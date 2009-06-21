require File.join(File.dirname(__FILE__), '..','test_helper.rb')
require File.join(File.dirname(__FILE__), '..','..','lib','relative_path')

RequestMock = Struct.new("Request",
                         :request_uri, :protocol,
                         :protocol,:host_with_port)

class DummyView < ActionView::Base
end

class DummyController < ActionController::Base
  attr_accessor :template
  include RelativePath
  self.template_root = "#{File.dirname(__FILE__)}/../fixtures/"

  def self.controller_path 
    "dummy"
  end

  def index
    render :inline => "index"
  end

  def edit
    render :inline => "<%= url_for :action => 'edit' %>"
  end

  def edit2
    @url = url_for :action => 'edit'
    render :inline => "<%= @url %>"
  end

  def link
    render :inline => "<%= link_to('name',{:action => 'link'}) %>"
  end

  def link2
    render :inline => "<%= link_to_unless_current('name',{:action => 'link'}) %>"
  end

  def redirect
    redirect_to :action => "link"
  end

  def javascript
    render :inline => "<%= javascript_include_tag 'sample' %>"
  end

  def current
    render :inline => "<%= current_page? :action => 'current' %>"
  end

  def current2
    render :inline => "<%= current_page? :action => 'current' %>"
  end

  def purchase
    render :inline => "<%= purchase_url :id => 10 %>"
  end
  
  def rescue_action e
    raise e
  end
end

class DummyNotIncludeRelativePathController < ActionController::Base
  def self.controller_path 
    "dummy_not_include_relative_path"
  end

  def edit
    render :inline => "<%= url_for :action => 'edit' %>"
  end
end

class CurrentControllerTest < Test::Unit::TestCase
  def setup
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @controller = DummyController.new
  end

  def test_url_for1
    @request.set_REQUEST_URI "/dummy/index"
    get "edit"
    assert_equal("../dummy/edit",@response.body)
  end

  def test_url_for2
    @request.set_REQUEST_URI "/dummy"
    get "edit"
    assert_equal("./dummy/edit",@response.body)
  end

  def test_url_for3
    @request.set_REQUEST_URI "/another_controller"
    get "edit"
    assert_equal("./dummy/edit",@response.body)
  end

  def test_url_for4
    @request.set_REQUEST_URI "/another_controller/index"
    get "edit"
    assert_equal("../dummy/edit",@response.body)
  end

  def test_url_for5
    @request.set_REQUEST_URI "/dummy/index"
    get "edit"
    assert_equal("../dummy/edit",@response.body)
  end

  def test_url_for6
    @controller = DummyNotIncludeRelativePathController.new
    @request.set_REQUEST_URI "/dummy_not_include_relative_path/index"
    get "edit"
    assert_equal("/dummy_not_include_relative_path/edit",@response.body)
  end

  def test_javascript_include_path
    @request.set_REQUEST_URI "/dummy/index"
    get "javascript"
    
  end

  def test_link
    @request.set_REQUEST_URI "/dummy/index"
    get "link"
    assert_equal('<a href="../dummy/link">name</a>',@response.body)
  end

  def test_link2
    @request.set_REQUEST_URI "/dummy/index"
    get "link2"
    assert_equal('<a href="../dummy/link">name</a>',@response.body)
  end

  def test_link3
    @request.set_REQUEST_URI "/dummy/link"
    get "link2"
    assert_equal('name',@response.body)
  end

  def test_redirect
    @request.set_REQUEST_URI "/dummy/redirect"
    get "redirect"
    assert_response(:redirect)
    assert_equal('../dummy/link',@response.redirect_url)
  end

  def test_javascript
    @request.set_REQUEST_URI "/dummy"
    get "javascript"
    assert_equal('<script src="./javascripts/sample.js" type="text/javascript"></script>',@response.body)
  end

  def test_javascript2
    @request.set_REQUEST_URI "/dummy/index"
    get "javascript"
    assert_equal('<script src="../javascripts/sample.js" type="text/javascript"></script>',@response.body)
  end

  def test_current
    @request.set_REQUEST_URI "/dummy/current"
    get "current"
    assert_equal('true',@response.body)
  end

  def test_current2
    @request.set_REQUEST_URI "/dummy/current2"
    get "current2"
    assert_equal('false',@response.body)
  end

  def test_xhr
    @request.env["HTTP_REFERER"] = "http://localhost/dummy/current"
    xml_http_request :get,"edit"
    assert_equal("../dummy/edit",@response.body)
  end

  def test_xhr2
    @request.env["HTTP_REFERER"] = "http://localhost/dummy"
    xml_http_request :get,"edit"
    assert_equal("./dummy/edit",@response.body)
  end

#   def test_routing
#     with_purchase_routing do 
#       @request.set_REQUEST_URI "/dummy/index"
#       get "purchase"
#       assert_equal("../products/10/purchase",@response.body)
#     end
#   end

#   def with_purchase_routing
#     with_routing do |set|
#       set.draw do |map|
#         map.purchase 'products/:id/purchase',:controller => 'dummy',
#           :action => 'purchase'
#       end
#       yield
#     end
#   end


end


