# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '9433922a4210a97a5b9bd1cb1300048a'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  
	def get_ip_address 			
		request.remote_ip 
	end		
	
	
	before_filter :init  
  
  MY_LOGGER = Logger.new("#{RAILS_ROOT}/log/mylogger.log")

  
  #corrige acentos
  def init  
    if request.xhr?
      headers["Content-Type"] = "text/javascript; charset=utf-8"
      WIN32OLE.codepage = WIN32OLE::CP_UTF8
    else
      headers["Content-Type"] = "text/html; charset=utf-8"
      WIN32OLE.codepage = WIN32OLE::CP_UTF8
    end
  end   
  
	
end
