//
//  LuaTests_iOS.m
//  LuaTests_iOS
//
//  Created by Mark Pauley on 12/10/13.
//  Copyright (c) 2013 Lua. All rights reserved.
//

#import <XCTest/XCTest.h>

#include <lua/lua.h>
#include <lua/lualib.h>
#include <lua/lauxlib.h>

// Returns x ** y, x to the yth power
int simpleExpFunction(lua_State* state) {
  int numArgs = lua_gettop(state);
  if(numArgs != 2) {
    return luaL_error(state, "simpleExpFunction expected 2 integer arguments!");
  }
  
  // Arguments appear in the stack in FIFO order.
  int isInt = 0;
  lua_Integer x = lua_tointegerx(state, -2, &isInt);
  if(!isInt) {
    return luaL_error(state, "first argument wasn't an int!");
  }
  lua_Integer y = lua_tointegerx(state, -1, &isInt);
  if(!isInt) {
    return luaL_error(state, "second argument wasn't an int!");
  }
  lua_pop(state, 2);
  long result = 1;
  for(; y > 0; y--) {
    result *= x;
  }
  lua_pushinteger(state, result);
  return 1;
}

static const struct luaL_Reg TestLib[] = {
  {"exp", simpleExpFunction},
  {NULL, NULL}
};

// Likely not used, but good for an example..
int luaopen_TestLib(lua_State *state) {
  luaL_newlib(state, TestLib);
  return 1;
}


@interface LuaTests_iOS : XCTestCase {
  lua_State* _state;
}

@end

@implementation LuaTests_iOS

- (void)setUp {
  [super setUp];
  NSString* bundleDir = [[NSBundle bundleForClass:[self class]] resourcePath];
  NSString* scriptPath = [bundleDir stringByAppendingPathComponent:@"chapter_6.lua"];
  _state = luaL_newstate();
  luaL_openlibs(_state);
  XCTAssertFalse(luaL_loadfile(_state, scriptPath.UTF8String), @"Failed to load the lua scripts");
  XCTAssertFalse(lua_pcall(_state, 0, 0, 0), @"Failed to run the lua scripts");
  
  
  scriptPath = [bundleDir stringByAppendingPathComponent:@"coroutine_tests.lua"];
  XCTAssertFalse(luaL_loadfile(_state, scriptPath.UTF8String), @"Failed to load the lua script");
  XCTAssertFalse(lua_pcall(_state, 0, 1, 0), @"Failed to run the lua scripts");
  XCTAssertEqual(1, lua_gettop(_state), @"Script didn't return the right number of values");
  XCTAssertEqual(LUA_TTABLE, lua_type(_state, -1), @"Script didn't return a module");
  lua_setglobal(_state, "TestStateMachine");
  
  
  // It looks like we need to eagerly require the external modules before we go running lua scripts, or
  //  we may fail to load the external module. It would be nice to be able to do this lazily, but
  //  honestly it probably isn't that big of a deal.
  luaL_requiref(_state, "TestLib", luaopen_TestLib, 0);
  XCTAssertEqual(1, lua_gettop(_state), @"Failed to require TestLib");
  lua_pop(_state, 1);
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the class.
  [super tearDown];
  lua_close(_state);
}

- (void)testSimpleInlineScript {
  char* inlineScript = "function returnFour() return 2 + 2; end";
  XCTAssertFalse(luaL_loadstring(_state, inlineScript));
  XCTAssertFalse(lua_pcall(_state, 0, 0, 0), @"Failed to run the simple inline script");
  XCTAssertEqual(0, lua_gettop(_state), @"script returned the wrong number of results");
  lua_getglobal(_state, "returnFour");
  XCTAssertFalse(lua_pcall(_state, 0, 1, 0), @"function call failed");
  XCTAssertEqual(1, lua_gettop(_state), @"function returned wrong number of values");
  int isNum = 0;
  int returnValue = lua_tointegerx(_state, -1, &isNum);
  XCTAssertTrue(isNum, @"return value isn't a number");
  XCTAssertEqual(4, returnValue, @"inline script returned an unexpected value");
  lua_pop(_state, 1);
}

- (void)testRunLoadedScript_function {
  char* inlineScript = "function squared(x) return x * x; end";
  XCTAssertFalse(luaL_loadstring(_state, inlineScript), @"Failed to run the inline script");
  XCTAssertFalse(lua_pcall(_state, 0, 0, 0), @"Failed to run the inline script");
  XCTAssertEqual(0, lua_gettop(_state), @"script returned the wrong number of results");
  // push the derivative function onto the stack
  lua_getglobal(_state, "derivative");
  // push squared function onto the stack (will be the first argument to the derivative function)
  lua_getglobal(_state, "squared");
  XCTAssertFalse(lua_pcall(_state, 1, 1, 0), @"function call failed");
  XCTAssertEqual(1, lua_gettop(_state), @"function returned wrong number of values");
  XCTAssertEqual(LUA_TFUNCTION, lua_type(_state, -1), @"function returned value of type %s",
                 lua_typename(_state, -1));
  // push an argument onto the stack..
  lua_pushnumber(_state, 12.0);
  // call the function => derivative(squared(12.0)) == 24.0
  XCTAssertFalse(lua_pcall(_state, 1, 1, 0), @"function call failed");
  XCTAssertEqual(1, lua_gettop(_state), @"function returned wrong number of arguments");
  int isNum = 0;
  lua_Number returnValue = lua_tonumberx(_state, -1, &isNum);
  XCTAssertEqual(1, isNum, @"function didn't return a number!");
  XCTAssertEqualWithAccuracy(24.0, returnValue, 0.001, @"function returned an unexpected value!");
  lua_pop(_state, 1);
}

// I predict that pushing c-functions onto the stack will be super useful.
//  probably a great trick for creating bridged C++ / Obj-C objects. (pauley)
-(void)testRunCustomCFunction {
  lua_pushcfunction(_state, simpleExpFunction);
  lua_pushinteger(_state, 3);
  lua_pushinteger(_state, 4);
  XCTAssertFalse(lua_pcall(_state, 2, 1, 0), @"failed to call cfunction (simpleExpFunction)");
  XCTAssertEqual(1, lua_gettop(_state), @"function returned wrong number of arguments");
  int isInt = 0;
  lua_Integer returnValue = lua_tointegerx(_state, -1, &isInt);
  XCTAssertTrue(isInt, @"function didn't return an integer!");
  XCTAssertEqual(81, returnValue, @"function didn't work as expected!");
  lua_pop(_state, 1);
}

-(void)testLoadLibrary {
  char* inlineScript = "TestLib = require \"TestLib\"; \n\
  function myExp(x, y) return TestLib.exp(x, y); end";
  XCTAssertFalse(luaL_loadstring(_state, inlineScript), @"Failed to load the inline script");
  XCTAssertFalse(lua_pcall(_state, 0, 0, 0), @"Failed to run the inline script");
  XCTAssertEqual(0, lua_gettop(_state), @"script returned the wrong number of results");
  // push the function onto the stack
  lua_getglobal(_state, "myExp");
  // push the args (x, y)
  lua_pushinteger(_state, 3);
  lua_pushinteger(_state, 4);
  XCTAssertFalse(lua_pcall(_state, 2, 1, 0), @"Failed to run the defined function");
  XCTAssertEqual(1, lua_gettop(_state), @"Script returned wrong number of results");
  int isInt = 0;
  lua_Integer returnValue = lua_tointegerx(_state, -1, &isInt);
  XCTAssertTrue(isInt, @"result was not an int as expected");
  XCTAssertEqual(81, returnValue, @"function didn't work as expected!");
  lua_pop(_state, 1);
}

// Testing lua cooperitive multitasking (A.K.A. coroutines or continuations)
-(void)testLuaThreads {
  char* inlineScript = "return TestStateMachine.new()";
  XCTAssertFalse(luaL_loadstring(_state, inlineScript), @"Failed to load the inline script");
  XCTAssertFalse(lua_pcall(_state, 0, 1, 0), @"Failed to run the inline script");
  XCTAssertEqual(1, lua_gettop(_state), @"script returns the wrong number of results");
  
  XCTAssertTrue(lua_isthread(_state, -1), @"script didn't return a thread");
  lua_State* thread = lua_tothread(_state, -1);
  int ref = luaL_ref(_state, LUA_REGISTRYINDEX);
  lua_gc(_state, LUA_GCRESTART, 0);
  lua_gc(_state, LUA_GCCOLLECT, 0);
  // It looks like you pass the thread as the "state" and the global thread as the "from"
  //  This is equivalent to calling coroutine.resume(thread) from _state
  XCTAssertEqual(LUA_YIELD, lua_resume(thread, _state, 0), @"error running thread!");
  // resume returns status, value
  XCTAssertEqual(1, lua_gettop(thread), @"thread returned the wrong number of results");
  int isInt = 0;
  lua_Integer returnValue = lua_tointegerx(thread, -1, &isInt);
  XCTAssertTrue(isInt, @"thread returned a non-int value");
  XCTAssertEqual(1, returnValue, @"thread returned an unexpected value!");
  lua_pop(thread, 1);
  
  XCTAssertEqual(LUA_YIELD, lua_resume(thread, _state, 0), @"error running thread");
  XCTAssertEqual(1, lua_gettop(thread), @"thread returned the wrong number of results");
  isInt = 0;
  returnValue = lua_tointegerx(thread, -1, &isInt);
  XCTAssertTrue(isInt, @"thread returned a non-int value");
  XCTAssertEqual(2, returnValue, @"thread returned an unexpected value!");
  lua_pop(thread, 1);
  XCTAssertEqual(LUA_OK, lua_resume(thread, _state, 0), @"error running thread");
  XCTAssertEqual(1, lua_gettop(thread), @"thread returned the wrong number of results");
  isInt = 0;
  returnValue = lua_tointegerx(thread, -1, &isInt);
  XCTAssertTrue(isInt, @"thread returned a non-int value");
  XCTAssertEqual(3, returnValue, @"thread returned an unexpected value!");
  lua_pop(thread, 1);
  // and now the thread is toast, we can nuke it.
  luaL_unref(_state, LUA_REGISTRYINDEX, ref);
  // run the simple inline script just for giggles.
  lua_gc(_state, LUA_GCCOLLECT, 0);
  [self testSimpleInlineScript];
}

@end
