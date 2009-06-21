ActiveRecord::Schema.define do

	create_table :inscricoes_forum_entidades do |t|
      t.string		:tipo_instituicao,	:limit	=>	50
      t.string		:nome,				:lmit	=>	300				
      t.text		:endereco
      t.string		:telefone,			:limit	=> 	50
      t.string		:email,				:limit	=>	100      
      t.string		:responsavel,		:limit	=>	300
      t.string		:ip,				:limit	=>	100
      t.datetime	:created_on      
    end

  end
