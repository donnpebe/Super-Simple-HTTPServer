require 'socket'
require 'uri'

# Files will be served from this directory
WEB_ROOT = './public'

# Map extensions to their content type
CONTENT_TYPE_MAPPING = {
  'html'  => 'text/html',
  'txt'   => 'text/plain',
  'css'   => 'text/css',
  'png'   => 'image/png',
  'jpg'   => 'image/jpeg',
  'jpeg'   => 'image/jpeg'

}

DEFAULT_CONTENT_TYPE = 'application/octet-stream'

def content_type(path) 
  ext = File.extname(path).split(".").last
  CONTENT_TYPE_MAPPING.fetch(ext, DEFAULT_CONTENT_TYPE)
end

def requested_file(request_line)
  request_uri = request_line.split(" ")[1]
  path = URI.unescape(URI(request_uri).path)
  clean = []

  # split the path into components
  parts = path.split("/")

  parts.each do |part|
    next if part.empty? || part == '.'
    part == '..' ? clean.pop : clean << part  
  end

  File.join(WEB_ROOT,*clean)
end

def not_found(socket, message)
  socket.print "HTTP/1.1 404 Not Found\r\n" +
               "Content-Type: text/plain\r\n" +
               "Content-Length: #{message.size}\r\n" +
               "Connection: close\r\n"
  socket.print "\r\n"
  socket.print message
  socket.close
end

# Find port argument or default to 7878
port = ARGF.argv.pop
port ||= 7878

server = TCPServer.new('localhost', port)

STDERR.puts "Simple WebServer Started (on port: #{port})..."

loop do
  socket = server.accept
  request_line = socket.gets

  # Log the request to the console for debugging
  STDERR.puts request_line

  path = requested_file(request_line)

  # Default to index.html
  path = File.join(path, 'index.html') if File.directory?(path) 

  if File.exist?(path) && !File.directory?(path)
    File.open(path, "rb") do |file|
      socket.print "HTTP/1.1 200 OK\r\n" +
                   "Content-Type: #{content_type(file)}\r\n" +
                   "Content-Length: #{file.size}\r\n" +
                   "Connection: close\r\n"
      socket.print "\r\n"

      # write the contents of the file to the socket
      IO.copy_stream(file, socket)
    end
    socket.close
  else
    not_found(socket, "File not found\n")
  end
end