require "rack/toolbar/version"

# Subclasses must define a render method which returns the snippet of HTML that will be inserted into the response body
# according to the INSERTION_METHOD and INSERTION_POINT.  By default this is set before to the closing </body> tag.

module Rack
  class Toolbar
    CONTENT_TYPE_REGEX = /text\/html|application\/xhtml\+xml/
    INSERTION_METHOD = :before  # alternatively :after
    INSERTION_POINT = "</body>" # alternatively "<body>" to have injection at the top of the body, or whatever else floats your boat.
    SNIPPET = <<EOS
  <h1>Welcome to rack-toolbar</h1>
  <ul>
    <li>Define render in Middleware subclass of Rack::Toolbar to return an HTML snippet.</li>
    <li>or</li>
    <li>Pass an HTML snippet as an argument and use Rack::Toolbar directly: Rack::Toolbar.new(snippet).</li>
    <li>or</li>
    <li>Redefine Rack::Toolbar::SNIPPET and ignore with the warnings.</li>
  </ul>
EOS

    def initialize(app, options = {})
      @app = app
      @options = options || {}
      @options[:snippet] ||= self.class::SNIPPET
      @options[:insertion_point] ||= self.class::INSERTION_POINT
      @options[:insertion_method] ||= self.class::INSERTION_METHOD
    end

    def call(env)
      @env = env
      @status, @headers, @response = @app.call(@env)
      [@status, @headers, self]
    end

    # Subclasses may override this method if they have alternate means of deciding which requests to modify.
    def okay_to_modify?
      return false if is_xhr?
      return false unless modifiable_content_type?
      true
    end

    def modifiable_content_type?
      @headers["Content-Type"] =~ self.class::CONTENT_TYPE_REGEX
    end

    def is_xhr?
      @headers["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    end

    def each(&block)
      if okay_to_modify?
        body = ""
        @response.each {|part| body << part }
        title_index = body.index('<title>')
        dt_index = body.index('<dt>From:</dt>')
        page_title = title_index && body[(title_index + 7)..(body.index('</title>') - 1)]
        if dt_index || ['Action Controller: Exception caught', 'Mailer Previews'].include?(page_title)
          index = body.rindex(@options[:insertion_point])
          if index
            if @options[:insertion_method] != :before
              index += @options[:insertion_point].length
            end
            body.insert(index, render)
            @headers["Content-Length"] = body.bytesize.to_s
            @response = [body]
          end
        end
      end
      @response.each(&block)
    end

    def render
      @options[:snippet]
    end

  end
end
