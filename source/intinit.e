--****
-- == intinit.e: Common command line initialization of interpreter

include std/cmdline.e
include std/text.e
include std/map.e as m

include global.e
include cominit.e
include error.e
include pathopen.e

sequence interpreter_opt_def = {}

--**
-- Merges values from map b into map a, using operation CONCAT
procedure merge_maps( m:map a, m:map b )
	sequence pairs = m:pairs( b )
	for i = 1 to length( pairs ) do
		m:put( a, pairs[i][1], pairs[i][2], m:CONCAT )
	end for
end procedure

include std/pretty.e
sequence pretty_opt = PRETTY_DEFAULT
pretty_opt[DISPLAY_ASCII] = 2
export procedure intoptions()

	
	expand_config_options()
	m:map opts = cmd_parse( get_options(),
		{ NO_VALIDATION_AFTER_FIRST_EXTRA }, Argv)
	
	sequence tmp_Argv = Argv
	Argv = Argv[1..2] & GetDefaultArgs()
	Argc = length(Argv)
	
	m:map default_opts = cmd_parse( get_options(), , Argv )
	merge_maps( opts, default_opts )
	
	Argv = tmp_Argv
	Argc = length( Argv )
	
	handle_common_options(opts)
	
	if length(m:get(opts, "extras")) = 0 then
		show_banner()
		puts(2, "\nERROR: Must specify the file to be interpreted on the command line\n\n")
		show_help( get_options() )

		abort(1)
	end if
	
	finalize_command_line(opts)
end procedure
