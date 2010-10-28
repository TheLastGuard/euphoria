namespace http2

include std/socket.e as sock
include std/net/url.e as url
include std/net/dns.e
include std/sequence.e
include std/text.e
include std/convert.e
include euphoria/info.e

constant USER_AGENT_HEADER = sprintf("User-Agent: Euphoria-HTTP/%d.%d\r\n", {
		version_major(), version_minor() })

enum R_HOST, R_PORT, R_PATH, R_REQUEST

--****
-- === Error Codes
--

public enum by -1
	ERR_MALFORMED_URL = -1,        -- -1
	ERR_INVALID_PROTOCOL,          -- -2
	ERR_INVALID_DATA,              -- -3
	ERR_INVALID_DATA_ENCODING,     -- -4
	ERR_HOST_LOOKUP_FAILED,        -- -5
	ERR_CONNECT_FAILED,            -- -6
	ERR_SEND_FAILED,               -- -7
	ERR_RECEIVE_FAILED             -- -8

--****
-- === Constants

public enum
	FORM_URLENCODED,
	MULTIPART_FORM_DATA

constant ENCODING_STRINGS = {
	"application/x-www-form-urlencoded",
	"multipart/form-data"
}

--
-- returns: { host, port, path, base_reqest }
--

function format_base_request(sequence request_type, sequence url, object headers)
	sequence request = ""

	object parsedUrl = url:parse(url)
	if atom(parsedUrl) then
		return ERR_MALFORMED_URL
	elsif not equal(parsedUrl[URL_PROTOCOL], "http") then
		return ERR_INVALID_PROTOCOL
	end if

	sequence host = parsedUrl[URL_HOSTNAME]

	integer port = parsedUrl[URL_PORT]
	if port = 0 then
		port = 80
	end if

	sequence path
	if sequence(parsedUrl[URL_PATH]) then
		path = parsedUrl[URL_PATH]
	else
		path = "/"
	end if

	if sequence(parsedUrl[URL_QUERY_STRING]) then
		path &= "?" & parsedUrl[URL_QUERY_STRING]
	end if

	request = sprintf("%s %s HTTP/1.0\r\nHost: %s:%d\r\n", {
		request_type, path, host, port })

	integer has_user_agent = 0
	integer has_connection = 0

	if sequence(headers) then
		for i = 1 to length(headers) do
			object header = headers[i]
			if equal(header[1], "User-Agent") then
				has_user_agent = 1
			elsif equal(header[1], "Connection") then
				has_connection = 1
			end if

			request &= sprintf("%s: %s\r\n", header)
		end for
	end if

	if not has_user_agent then
		request &= USER_AGENT_HEADER
	end if
	if not has_connection then
		request &= "Connection: close\r\n"
	end if

	return { host, port, path, request }
end function

--
-- encode a sequence of key/value pairs
--

function form_urlencode(sequence kvpairs)
	sequence data = ""

	for i = 1 to length(kvpairs) do
		object kvpair = kvpairs[i]

		if i > 1 then
			data &= "&"
		end if

		data &= kvpair[1] & "=" & encode(kvpair[2])
	end for

	return data
end function

function multipart_form_data_encode(sequence kvpairs)
	return ""
end function

--
-- Send an HTTP request
--

function execute_request(sequence host, integer port, sequence request, integer timeout)
	object addrinfo = host_by_name(host)
	if atom(addrinfo) or length(addrinfo) < 3 or length(addrinfo[3]) = 0 then
		return ERR_HOST_LOOKUP_FAILED
	end if

	sock:socket sock = sock:create(sock:AF_INET, sock:SOCK_STREAM, 0)

	if sock:connect(sock, addrinfo[3][1], port) != sock:OK then
		return ERR_CONNECT_FAILED
	end if

	if not sock:send(sock, request, 0) = length(request) then
		sock:close(sock)
		return ERR_SEND_FAILED
	end if

	atom start_time = time()
	integer got_header = 0, content_length = 0
	sequence content = ""
	sequence body = ""
	sequence headers = {}
	while time() - start_time < timeout label "top" do
		if got_header and length(content) = content_length then
			exit
		end if

		object has_data = sock:select(sock, {}, {}, timeout)
		if (length(has_data[1]) > 2) and equal(has_data[1][2],1) then
			object data = sock:receive(sock, 0)
			if atom(data) then
				if data = 0 then
					-- zero bytes received, we the 'data' waiting was
					-- a disconnect.
					exit "top"
				else
					return ERR_RECEIVE_FAILED
				end if
			end if

			content &= data

			if not got_header then
				integer header_end_pos = match("\r\n\r\n", content)
				if header_end_pos then
					-- we have a header, let's parse it and figure out
					-- the content length.
					sequence raw_header = content[1..header_end_pos]
					content = content[header_end_pos + 4..$]

					sequence header_lines = split(raw_header, "\r\n")
					headers = append(headers, split(header_lines[1], " "))
					for i = 2 to length(header_lines) do
						object header = header_lines[i]
						sequence this_header = split(header, ": ", , 1)
						this_header[1] = lower(this_header[1])
						headers = append(headers, this_header)

						if equal(this_header[1], "content-length") then
							content_length = to_number(this_header[2])
						end if
					end for

					got_header = 1
				end if
			end if
		end if
	end while

	return { headers, content }
end function

--**
-- Post data to a HTTP resource.
--
-- Returns:
--   An integer error code or a 2 element sequence. Element 1 is a sequence
--   of key/value pairs representing the result header information. element
--   2 is the body of the result.
--
--   If result is a negative integer, that represents a local error condition.
--
--   If result is a positive integer, that represents a HTTP error value from
--   the server.
--
-- See Also:
--   [[:http_get]]
--

public function http_post(sequence url, object data, object headers = 0,
		integer follow_redirects = 10, integer timeout = 15)
	if not sequence(data) or length(data) = 0 then
		return ERR_INVALID_DATA
	end if

	object request = format_base_request("POST", url, headers)
	if atom(request) then
		return request
	end if

	integer data_type
	if atom(data[1]) then
		if data[1] < 1 or data[1] > 2 then
			return ERR_INVALID_DATA_ENCODING
		end if

		data_type = data[1]
		data = data[2]
	else
		data_type = FORM_URLENCODED
	end if

	-- data now contains either a string sequence already encoded or
	-- a sequence of key/value pairs to be encoded. We know the length
	-- is greater than 0, so check the first element to see if it's a
	-- sequence or an atom. That will tell us what we have.
	--
	-- If we have key/value pairs then we will need to encode that data
	-- according to our data_type.

	if sequence(data[1]) then
		-- We have key/value pairs
		if data_type = FORM_URLENCODED then
			data = form_urlencode(data)
		else
			data = multipart_form_data_encode(data)
		end if
	end if

	request[R_REQUEST] &= sprintf("Content-Type: %s\r\n", { ENCODING_STRINGS[data_type] })
	request[R_REQUEST] &= sprintf("Content-Length: %d\r\n", { length(data) })
	request[R_REQUEST] &= "\r\n"
	request[R_REQUEST] &= data

	return execute_request(request[R_HOST], request[R_PORT], request[R_REQUEST], timeout)
end function

--**
-- Get a HTTP resource.
--
-- Returns:
--   An integer error code or a 2 element sequence. Element 1 is a sequence
--   of key/value pairs representing the result header information. Element
--   2 is the body of the result.
--
--   If result is a negative integer, that represents a local error condition.
--
--   If result is a positive integer, that represents a HTTP error value from
--   the server.
--
-- See Also:
--   [[:http_post]]
--

public function http_get(sequence url, object headers = 0, integer follow_redirects = 10,
		integer timeout = 15)
	object request = format_base_request("GET", url, headers)
	if atom(request) then
		return request
	end if

	-- No more work necessary, terminate the request with our ending CR LF
	request[R_REQUEST] &= "\r\n"

	return execute_request(request[R_HOST], request[R_PORT], request[R_REQUEST], timeout)
end function
