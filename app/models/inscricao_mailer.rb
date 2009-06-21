class InscricaoMailer < ActionMailer::Base

  ActionMailer::Base.delivery_method = :smtp
  ActionMailer::Base.raise_delivery_errors = true
  ActionMailer::Base.default_charset = "UTF-8"
  
  ActionMailer::Base.smtp_settings = {
    :address => "10.150.150.165" ,
    :port => 25,
    :domain => "procempa.com.br"
  }
  
  
  
  def envia_confirmacao(inscrito)
    @subject = "Confirmacao de inscricao  - Ciclo de Debates sobre Reforma Politica"
    @recipients = []
    @recipients << inscrito.email    
    @recipients << 'chuvisco@camarapoa.rs.gov.br'
    @recipients << 'escola@camarapoa.rs.gov.br'
    #@recipients << 'rp@camarapoa.rs.gov.br'
    @from = "CMPA - Escola do Legislativo<escola@camarapoa.rs.gov.br>"
    @body["inscrito"] = inscrito
  end
  



end
