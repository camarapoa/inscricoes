class Inscrito < ActiveRecord::Base
	
	
	validates_presence_of	:nome, :endereco, :numero, :telefone
	validates_uniqueness_of	:nome
	validates_format_of     :email, 
							:with	=>	/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i,
							:message    => ' inválido'							
		
	
end