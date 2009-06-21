class InscricoesController < ApplicationController
	
	layout 'inscritos'
	
	def index
		@inscricao = Inscrito.new
	end
	
	def new
	end
	
	def create
	  begin
		  @inscrito = Inscrito.new(params[:inscrito])
		  @inscrito.ip = get_ip_address
		  @res_save = @inscrito.save
		  if @res_save
		    @res_envio = create_confirma(@inscrito)  		    
		    if !@res_envio
		      flash[:message] = "<div class='info'>Sua inscrição foi efetuada com sucesso, mas houve problemas com envio do e-mail de confirmação.<br/>"
		      flash[:message] += "Contate a Assessoria de Informática da CMPA no telefone 3220-4334 e informe o número #{@inscrito.id}</div>"
		    end		                    
  			flash[:message] = "<div class='notice'>Sua inscrição foi efetuada com sucesso.<br/>Verifique a confirmação no e-mail informado.</div>" if @res_envio
  			redirect_to	'/reforma/inscricoes'
  		else			
  			render 	:action => :new
  		end
  	rescue Exception => e
      @e = e
      MY_LOGGER.debug("[#{Time.now}] [#{@ip}] #{@e}")
    end   
	end
	
	
	def create_confirma(inscrito)  
    begin
      email = InscricaoMailer.create_envia_confirmacao(inscrito)
      email.set_content_type("text/html" )        
      InscricaoMailer.deliver(email)  
    rescue Exception => e
      @e = e
      MY_LOGGER.debug("[#{Time.now}] [#{inscrito.ip}] #{@e}")      
      return false
    end  
    return true
  end	
	
end