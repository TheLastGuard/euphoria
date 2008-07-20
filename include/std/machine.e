-- (c) Copyright 2008 Rapid Deployment Software - See License.txt
--
-- **Page Contents**
--
-- <<LEVELTOC depth=2>>
--

--****
-- Dynamic calling of routines
--=== Routines
--==== Accessing Euphoria coded routines

--**
-- Signature
-- global function routine_id(sequence routine_name)
--
-- Description:
-- Return an integer id number for a user-defined Euphoria procedure or function.
--
-- Parameters:
-- 		# ##routine_name##: a string, the name of the procedure or function.
--
-- Returns:
-- An **integer**, known as a routine id, -1  if the named routine can't be found, else zero or more.
--
-- Errors:
-- ##routine_name## should not exceed 1,024 characters.
--
-- Comments:
-- The id number can be passed to [[:call_proc]]() or [[:call_func]](), to indirectly call
-- the routine named by ##routine_name##. This id depends on the internal process of 
-- parsing your code, not on ##routine_name##.
--
-- The routine named ##routine_name## must be visible, i.e. callable, at the place where
-- ##routine_id##() is used to get the id number. If it is not, -1 is returned.
--
-- Indirect calls to the routine can appear earlier in the program than the definition of the routine,
-- but the id number can only be obtained in code that comes after the definition
-- of the routine - see example 2 below.
--
-- Once obtained, a valid routine id can be used at any place in the program to call
-- a routine indirectly via [[:call_proc]]()/[[:call_func]](), including at places where
-- the routine is no longer in scope.
--
-- Some typical uses of routine_id() are:
--
-- # Calling a routine that is defined later in a program.
-- # Creating a subroutine that takes another routine as a parameter. (See Example 2 below)
-- # Using a sequence of routine id's to make a case (switch) statement.
-- # Setting up an Object-Oriented system.
-- # Getting a routine id so you can pass it to [[:call_back]](). (See [[../docs/platform.txt]])
-- # Getting a routine id so you can pass it to [[:task_create]](). (See [[../docs/tasking.txt]])
--
-- Note that C routines, callable by Euphoria, also have routine id's.
-- See [[:define_c_proc]]() and [[:define_c_func]]().
--
-- Example 1:
-- <eucode>  
--  procedure foo()
--     puts(1, "Hello World\n")
-- end procedure
-- 
-- integer foo_num
-- foo_num = routine_id("foo")
-- 
-- call_proc(foo_num, {})  -- same as calling foo()
-- </eucode>
--  
-- Example 2:  
-- <eucode>
--  function apply_to_all(sequence s, integer f)
--     -- apply a function to all elements of a sequence
--     sequence result
--     result = {}
--     for i = 1 to length(s) do
--         -- we can call add1() here although it comes later in the program
--         result = append(result, call_func(f, {s[i]}))
--     end for
--     return result
-- end function
-- 
-- function add1(atom x)
--     return x + 1
-- end function
-- 
-- -- add1() is visible here, so we can ask for its routine id
-- ? apply_to_all({1, 2, 3}, routine_id("add1"))
-- -- displays {2,3,4}
-- </eucode>
--  
-- See Also:
-- [[:call_proc]], [[:call_func]], [[:call_back]], [[:define_c_func]], [[:define_c_proc]], 
-- [[:task_create]], [[../docs/platform.txt]], [[../docs/dynamic.txt]]

--**
-- Signature
-- global function call_func(integer id, sequence args)
--
-- Description:
--  Call the user-defined Euphoria function by routine id.
--
-- Parameters:
-- 		# ##id##: an integer, the routine id of the function to call
--		# ##args##: a sequence, the parameters to pass to the function.
--
-- Returns:
-- The value the called function returns.
--
-- Errors:
-- If ##id## is negative or otherwise unknown, an error occurs.
--
-- If the length of ##args## is not the number of patameters the function takes, an error occurs.
--
-- Comments: 
-- ##id## must be a valid routine id returned by [[:routine_id]]().
--
-- ##args## must be a sequence of argument values of length n, where n is the number of
-- arguments required by the called function. Defaulted parameters currently cannot be
-- synthesized while making a dynamic call.
--
-- If the function with id ##id## does not take any arguments then ##args## should be ##{}##.
--
-- Example 1:
-- [[../demo/csort.ex]]
--
-- See Also:
-- [[:call_proc]], [[:routine_id]], [[:c_func]]
-- 
--**
-- Signature:
-- global procedure call_proc(integer id, sequence args)
-- Description:
-- Call a user-defined Euphoria procedure by routine id.
--
-- Parameters:
-- 		# ##id##: an integer, the routine id of the procedure to call
--		# ##args##: a sequence, the parameters to pass to the function.
--
-- Errors:
-- If ##id## is negative or otherwise unknown, an error occurs.
--
-- If the length of ##args## is not the number of patameters the function takes, an error occurs.
--
-- Comments: 
-- ##id## must be a valid routine id returned by [[:routine_id]]().
--
-- ##args## must be a sequence of argument values of length n, where n is the number of
-- arguments required by the called procedure. Defaulted parameters currently cannot be
-- synthesized while making a dynamic call.
--
-- If the procedure with id ##id## does not take any arguments then ##args## should be ##{}##.
--
-- Example 1:
-- <eucode>
--  export integer foo_id
--
-- procedure x()
--     call_proc(foo_id, {1, "Hello World\n"})
-- end procedure
-- 
-- procedure foo(integer a, sequence s)
--     puts(a, s)
-- end procedure
-- 
-- foo_id = routine_id("foo")
-- 
-- x()
-- </eucode>
--  
-- See Also: 
-- [[:call_func]], [[:routine_id]], [[:c_proc]]

--****
--==== Accessing Euphoria internals dynamically

--**
-- Signature:
-- global function machine_func(integer machine_id, object args)
--
-- Description:
-- Perform a machine-specific operation that returns a value.
--
-- Returns:
-- Depends on the called internal facility.
--
-- Comments:
-- This function us mainly used by the standard library files to implement machine dependent operations.
-- such as graphics and sound effects. This routine should normally be called indirectly
-- via one of the library routines in a Euphoria include file.
-- User programs normally do not need to call ##machine_func##.
--
-- A direct call might cause a machine exception if done incorrectly.
--
-- See Also: 
-- [[:machine_func]]

--**
-- Signature:
-- global procedure machine_proc(integer machine_id, object args)
--
-- Description:
-- Perform a machine-specific operation that does not return a value.
--
-- Comments:
-- This procedure us mainly used by the standard library files to implement machine dependent operations.
-- such as graphics and sound effects. This routine should normally be called indirectly
-- via one of the library routines in a Euphoria include file.
-- User programs normally do not need to call ##machine_proc##.
--
-- A direct call might cause a machine exception if done incorrectly.
--
-- See Also: 
-- [[:machine_proc]]



ifdef SAFE then
	export include safe.e
	ifdef DOS32 then
		export include .\dos\safe.e
	end ifdef
else
	export include memory.e
	ifdef DOS32 then
		export include .\dos\memory.e
	end ifdef
end ifdef



