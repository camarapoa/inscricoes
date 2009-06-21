# Relative Path plugin
#
## usage 1 :
# class YourController < ApplicationController
#   include RelativePath
# end

## usage 2 :
# class ApplicationController
#   include RelativePath
# end

## An example to use Static File Filter is below:
# RelativePath.register_filter /\.css/,%r(src="(\.\./themes.+?)") do |env,match|
#  referer = env["HTTP_REFERER"]
#  if (req_uri = env["CLIENT_REQUEST_URI"]) && referer then
#    referer = URI(referer)
#    rel_path = req_uri + match[1] - referer
#    "src=\"#{rel_path}\""
#  else
#    match[0]
#  end
# end
##   first argument /\.css/ is a regular expression to specify files 
## you want to proccess.
##   This filter replace strings matched by the second argument
## with block's evaluated value.
##   block's first argument *env* is a hash. The content of env is 
## almost equal to HTTP Request header fields 
## except that it is added CLIENT_REQUEST_URI.
## env["CLIENT_REQUEST_URI"] contains an induced uri that is 
## on user's browser. Keep it in mind that the inducing method is 
## imperfect. CLIENT_REQUEST_URI is useful when your CSS needs 
## relative path from a user's browsing uri.
##   block's second argument *match* is MatchData object that 
## is matched by the regular expression of the second argument
## of register_filter method.
##   Because the matched string is replaced by the block's 
## evaluated value, you have to return match[0] when you don't want 
## to change anything.
#
## An example to use Togglable Relative Path feature below:
# <% with_relative_path_disabled do %>
#     <td><%= link_to 'Show', :action => 'show', :id => user_id, :only_path => false %></td>
# <%   with_relative_path_enabled do %>
#     <td><%= link_to 'Edit', :action => 'edit', :id = user_id %></td>
# <%   end %>
#     <td><%= link_to 'Destroy', { :action => 'destroy', :id => user_id }, :confirm => 'Are you sure?', :method => :post %></td>
# <% end %>
#



module RelativePath
  def self.append_features(klass)
    @klass = klass
    super klass
    klass.extend(ClassMethods)
    klass.init_relative_path
  end

  def relative_path_prefix
    parent_dir = "."
    path = ""
    if request.xhr?
      referer = URI.parse(request.env["HTTP_REFERER"]).path
      if referer =~ %r((/#{self.class.controller_path}.+))
        path = $1
      end
    else
      path = URI.parse(request.env["REQUEST_URI"]).path
      root = request.relative_url_root.to_s
      path.gsub!(root,"")
    end
    count = path.count("/") - 1
    if count > 0
      parents = [".."] * count
      parent_dir = parents.join("/")
    end
    parent_dir
  end
  
  def url_for(options = {}, *parameters_for_method_reference)
    unless self.class.relative_path_enabled?
      return super(options,parameters_for_method_reference)
    end

    options = {} if options.nil?

    case options
    when Hash
      options[:only_path] = true
      options[:skip_relative_url_root] = true
      url = super(options,parameters_for_method_reference)
      parent_dir = relative_path_prefix
      url = "#{parent_dir}#{url}"
      return url
    else
      return super(options,parameters_for_method_reference)
    end
  end
  
  def redirect_to(options = {}, *parameters_for_method_reference)
    unless self.class.relative_path_enabled?
      return super(options,parameters_for_method_reference)
    end

    case options
    when %r(^\.)
      raise DoubleRenderError if performed?
      response.redirect(options)
      response.redirected_to = options
      @performed_redirect = true
    when %r(^/)
      options = "#{relative_path_prefix}#{options}"
      redirect_to options,*parameters_for_method_reference
    when Hash
      options[:only_path] = true
      if parameters_for_method_reference.empty?
        redirect_to(url_for(options))
        response.redirected_to = options
      else
        redirect_to(url_for(options, *parameters_for_method_reference))
        response.redirected_to, response.redirected_to_method_params = options, parameters_for_method_reference
      end
    else
      super(options,parameters_for_method_reference)
    end
  end  
  
  def initialize_current_url
    super
    klass = self.class
    self.class.class_eval do
      view_class.class_eval do
        break if @already_redefined_for_relative_path
        @already_redefined_for_relative_path = true
        define_method(:compute_public_path) do |source,dir,ext|
          url = super source,dir,ext
          break url unless klass.relative_path_enabled?

          parent_dir = @controller.relative_path_prefix
          root = @controller.request.relative_url_root.to_s
          url.gsub!(root,"")
          url = "#{parent_dir}#{url}"
          url
        end
        define_method(:url_for) do |options,*parameters_for_method_reference|
          url = super options,parameters_for_method_reference
          break url unless klass.relative_path_enabled?

          if url =~ %r(^/) then
            parent_dir = @controller.relative_path_prefix
            root = @controller.request.relative_url_root.to_s
            url.gsub!(root,"")
            url = "#{parent_dir}#{url}"
          end
          url
        end
        define_method(:current_page?) do |options|
          if klass.relative_path_enabled?
            req_uri = @controller.request.request_uri
            rel_uri = CGI.escapeHTML(url_for(options))
            dir = File.join(File.dirname(req_uri),rel_uri)
            cur_uri = File.expand_path(dir)
            req_uri == cur_uri
          else
            super options
          end
        end
      end
    end
  
    set_relative_url_root
  end
  
  def set_relative_url_root
    if defined?(@@relative_url_root_callback)
      @@relative_url_root = @@relative_url_root_callback.call(self)
    elsif not defined?(@@relative_url_root) or 
        @@relative_url_root.nil? or @@relative_url_root.empty?
      @@relative_url_root = default_relative_url_root
    end
  end
  
  # this method is imperfect.
  def default_relative_url_root
    if referer = request.env["HTTP_REFERER"]
      path = URI(referer).path
      controller_path = self.class.controller_path
      if index = path.index(controller_path) then
        return path[0,index]
      end
    end
  end
  
  def self.disable_static_file_filter
    @static_file_filter_disabled = true
  end

  def self.static_file_filter_disabled?
    @static_file_filter_disabled
  end

  module StaticFileFilter
    @@filter_callbacks = nil
    def self.calc_client_request_uri h
      if referer = h["HTTP_REFERER"] then
        rel_root = RelativePath.relative_url_root.to_s.dup
        if rel_root.length > 0 and rel_root[-1].chr != "/" 
          rel_root << "/"
        end
        referer = URI(referer)
        client_request_uri = 
          case str = h["REQUEST_URI"]
          when URI
            uri = str
            referer + rel_root + ".#{uri.path}"
          when %r(^http://)
            uri = URI(str)
            referer + rel_root + ".#{uri.path}"
          when %r(^/)
            referer + rel_root + ".#{str}"
          else
            str
          end
        h["CLIENT_REQUEST_URI"] = client_request_uri
      end
    end
    
    def self.webrick_filter h
      return unless @@filter_callbacks
      calc_client_request_uri h
      @@filter_callbacks.each do |filename_regex,src_regex,callback|
        next unless h[:local_path] =~ filename_regex
        h[:io].instance_eval do
          @filter_callbacks ||= []
          @filter_callbacks << [src_regex,callback]
          @filter_env = h
          def read size
            body = super size
            @filter_callbacks.each do |src_regex,callback|
              body.gsub!(src_regex) do |*args|
                callback.call @filter_env,Regexp.last_match,*args
              end
            end
            return body
          end
        end
      end
    end
    
    def self.mongrel_filter h
      body = h[:io].string
      return body unless @@filter_callbacks
      calc_client_request_uri h
      @@filter_callbacks.each do |filename_regex,pattern,replace|
        next unless h[:local_path] =~ filename_regex
        body.gsub!(pattern) do |*args|
          replace.call h,Regexp.last_match
        end
      end
      return body
    end
    
    def self.register_filter filename_regex,pattern,&replace
      @@filter_callbacks ||= []
      @@filter_callbacks << [filename_regex,pattern,replace]
    end
  end

  # this method is also imperfect
  def self.induce_relative_url_root referer
    return unless referer
    path = URI(referer).path
    dirs = []
    temp_root = ActionController::Base.template_root
    if RAILS_ENV == "production" then
      if defined?(@@dirs) then
        dirs = @@dirs
      else
        @@dirs = Dir.entries(temp_root)
        dirs = @@dirs
      end
    else
      dirs = Dir.entries(temp_root)
    end
    dirs.each do |dir|
      absdir = File.join(temp_root,dir)
      next unless File.directory?(absdir)
      if index = path.index(dir) then
        @@relative_url_root = path[0,index]
      end
    end
  end

  module ClassMethods
    def init_relative_path
      enable_relative_path
      if defined?(WEBrick) then
        init_webrick
      end

      if defined?(Mongrel) then
        init_mongrel
      end

      init_abstract_request
    end

    def enable_relative_path
      @relative_path_enabled = true
    end

    def disable_relative_path
      @relative_path_enabled = false
    end

    def with_relative_path_enabled
      tmp = @relative_path_enabled
      enable_relative_path
      yield
      @relative_path_enabled = tmp
    end
    
    def with_relative_path_disabled
      tmp = @relative_path_enabled
      disable_relative_path
      yield
      @relative_path_enabled = tmp
    end

    def relative_path_enabled?
      case @relative_path_enabled
      when true
        return true
      when false
        return false
      end

      klass = self.superclass
      while klass < ActionController::Base
        case klass.instance_variable_get :@relative_path_enabled
        when true
          @relative_path_enabled = true
          return true
        when false
          @relative_path_enabled = false
          return false
        end
        klass = klass.superclass
      end
      @relative_path_enabled = true
      return true
    end

    def relative_url_root
      if defined?(@@relative_url_root)
        @@relative_url_root
      else
        ""
      end
    end
    
    def set_relative_url_root rel_root = nil,&callback
      if callback then
        @@relative_url_root_callback = callback
      elsif rel_root then
        @@relative_url_root = rel_root
      end
    end
    
    def register_filter *args,&callback
      StaticFileFilter.register_filter *args,&callback
    end

    def init_webrick
      klass = self
      WEBrick::HTTPResponse.class_eval do
        break if defined?(@setup_header_redefined)
        @setup_header_redefined = true
        unbound = instance_method :setup_header
        define_method :setup_header do 
          if klass.relative_path_enabled?
            location = @header['location']
            unbound.bind(self).call
            if location =~ %r(^\.) then
              @header['location'] = location
            end
          else
            unbound.bind(self).call
          end
        end
      end
      
      return if RelativePath.static_file_filter_disabled?
      HTTPServlet::DefaultFileHandler.class_eval do 
        break if defined?(@do_GET_redefined)
        @do_GET_redefined = true
        unbound = instance_method :do_GET
        define_method :do_GET do |req,res|
          ret = unbound.bind(self).call(req,res)
          break ret if RelativePath.static_file_filter_disabled?

          if res.body.is_a?(File)
            begin
              h = req.meta_vars.dup
              RelativePath.induce_relative_url_root h["HTTP_REFERER"]
              h.merge!({:local_path => @local_path,
                         :io => res.body,
                       })
              RelativePath::StaticFileFilter.webrick_filter h
            rescue => e
              $stderr.puts e.to_s
              $stderr.puts $@.first(5)
            end
          end
          break ret
        end
      end
    end

    def init_mongrel
      return if RelativePath.static_file_filter_disabled?

      Mongrel::DirHandler.class_eval do
        break if defined?(@send_file_redefined)
        @send_file_redefined = true

        unbound = instance_method :send_file

        define_method :send_file do |req_path,req,response,header_only|
          header_only ||= false
          socket_escaped = nil
          begin
            response.instance_eval do 
              socket_escaped = @socket
              @socket = StringIO.new("","w")
            end
            begin
              method = unbound.bind self
              ret = method.call req_path,req,response,header_only
            rescue => e
              $stderr.puts e.to_s
              $stderr.puts $@.first(5)
            end
            return ret
          ensure
            io = nil
            response.instance_eval do
              io = @socket
              @socket = socket_escaped
            end
            h = req.params.dup
            h.merge!({:local_path => req_path,
                       :io => io,
                     })
            RelativePath.induce_relative_url_root(h["HTTP_REFERER"])
            begin
              string = RelativePath::StaticFileFilter.mongrel_filter h
              response.instance_eval do 
                write(string)
              end
            rescue => e
              $stderr.puts e.to_s
              $stderr.puts $@.first(5)
            end
          end
        end
      end
    end

    def init_abstract_request
      ActionController::AbstractRequest.class_eval do 
        break if defined?(@relative_url_root_redefined)
        @relative_url_root_redefined = true
        define_method :relative_url_root do 
          @@relative_url_root ||=
            case 
            when @env["RAILS_RELATIVE_URL_ROOT"]
              @env["RAILS_RELATIVE_URL_ROOT"]
            when ENV["RAILS_RELATIVE_URL_ROOT"]
              ENV["RAILS_RELATIVE_URL_ROOT"]
            when server_software == 'apache'
              File.dirname(@env["SCRIPT_NAME"].to_s)
            when server_software.to_s.include?("lighttpd")
              File.dirname(@env["SCRIPT_NAME"].to_s).sub(%r(/$),"")
            else
              nil
            end
          @@relative_url_root = nil if @@relative_url_root == ""
        end
      end
    end
  end

  def enable_relative_path
    self.class.enable_relative_path
  end

  def disable_relative_path
    self.class.disable_relative_path
  end

  def with_relative_path_enabled
    self.class.with_relative_path_enabled do 
      yield
    end
  end

  def with_relative_path_disabled
    self.class.with_relative_path_disabled do
      yield
    end
  end
end

module RelativePathHelper
  def with_relative_path_enabled
    controller.with_relative_path_enabled do 
      yield
    end
  end

  def with_relative_path_disabled
    controller.with_relative_path_disabled do 
      yield
    end
  end
end

module ApplicationHelper
  include RelativePathHelper
end
