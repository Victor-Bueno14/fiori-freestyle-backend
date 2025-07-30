class ZCL_ZOV_DPC_EXT definition
  public
  inheriting from ZCL_ZOV_DPC
  create public .

public section.
protected section.

  methods MENSAGEMSET_CREATE_ENTITY
    redefinition .
  methods MENSAGEMSET_DELETE_ENTITY
    redefinition .
  methods MENSAGEMSET_GET_ENTITY
    redefinition .
  methods MENSAGEMSET_GET_ENTITYSET
    redefinition .
  methods MENSAGEMSET_UPDATE_ENTITY
    redefinition .
  methods OVCABSET_CREATE_ENTITY
    redefinition .
  methods OVCABSET_DELETE_ENTITY
    redefinition .
  methods OVCABSET_GET_ENTITY
    redefinition .
  methods OVCABSET_GET_ENTITYSET
    redefinition .
  methods OVCABSET_UPDATE_ENTITY
    redefinition .
  methods OVITEMSET_CREATE_ENTITY
    redefinition .
  methods OVITEMSET_DELETE_ENTITY
    redefinition .
  methods OVITEMSET_GET_ENTITY
    redefinition .
  methods OVITEMSET_GET_ENTITYSET
    redefinition .
  methods OVITEMSET_UPDATE_ENTITY
    redefinition .
private section.
ENDCLASS.



CLASS ZCL_ZOV_DPC_EXT IMPLEMENTATION.


  method MENSAGEMSET_CREATE_ENTITY.
  endmethod.


  method MENSAGEMSET_DELETE_ENTITY.
  endmethod.


  method MENSAGEMSET_GET_ENTITY.
  endmethod.


  method MENSAGEMSET_GET_ENTITYSET.
  endmethod.


  method MENSAGEMSET_UPDATE_ENTITY.
  endmethod.


  METHOD ovcabset_create_entity.

    "Variáveis
    DATA: lv_lastid TYPE int4.

    "Estruturas
    DATA: ls_cab    TYPE zovcab.

    "Criação de um objeto para armazenar e retornar mesagens via oData.
     DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    "Os dados da requisição são copiados para o er_entity.
    io_data_provider->read_entry_data(
      IMPORTING
        es_data = er_entity
    ).

    MOVE-CORRESPONDING er_entity TO ls_cab.

    ls_cab-criacao_data    = sy-datum.
    ls_cab-criacao_hora    = sy-uzeit.
    ls_cab-criacao_usuario = sy-uname.

    "Seleciona o último registro cadastrado.
    SELECT SINGLE MAX( ordemid )
       INTO lv_lastid
       FROM zovcab.

    ls_cab-ordemid = lv_lastid + 1.

    INSERT zovcab FROM ls_cab.

    IF sy-subrc IS NOT INITIAL.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao inserir ordem'
       ).

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocrreu um erro.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

    "Copia os dados gravados de volta para er_entity, que será retornado como resposta
    MOVE-CORRESPONDING ls_cab TO er_entity.

    "Converte a data e a hora local para um timestamp, e armazena no campo datacriacao
    "Time Zone é o fuso horário.
    CONVERT
      DATE ls_cab-criacao_data
      TIME ls_cab-criacao_hora
      INTO TIME STAMP er_entity-datacriacao
      TIME ZONE sy-zonlo.

  ENDMETHOD.


  method OVCABSET_DELETE_ENTITY.
  endmethod.


  METHOD ovcabset_get_entity.
    er_entity-ordemid = 1.
    er_entity-criadopor = 'Victor'.
    er_entity-datacriacao = '19700101000000'.
  ENDMETHOD.


  METHOD ovcabset_get_entityset.

    "Tabela Interna

    DATA: lt_cab TYPE STANDARD TABLE OF zovcab.

    "Estruturas

    DATA: ls_cab       TYPE zovcab.

    "et_entityset é o parâmetro que serve para retornar a lista de registros solicitados.
    "Estrutura responsável em manipular o et_entityset.
    DATA: ls_entityset LIKE LINE OF et_entityset.

    SELECT * INTO TABLE lt_cab FROM zovcab.

    LOOP AT lt_cab INTO ls_cab.

      CLEAR ls_entityset.

      MOVE-CORRESPONDING ls_cab TO ls_entityset.

      "Pelo nome dos campos serem diferentes, o move-corresponding não será efetivo,
      "por isso é necessário atribuir manualmente.
      ls_entityset-criadopor = ls_cab-criacao_usuario.

      "Pelo ls_cab trabalhar com o campo data e hora enquanto o entity-set trabalha com TIMESTAMP,
      "é necessário realizar essa conversão de data e hora para TIMESTAMP.
      CONVERT DATE ls_cab-criacao_data
              TIME ls_cab-criacao_hora
         INTO TIME STAMP ls_entityset-datacriacao
         TIME ZONE sy-zonlo.

      APPEND ls_entityset TO et_entityset.

    ENDLOOP.

  ENDMETHOD.


  method OVCABSET_UPDATE_ENTITY.
  endmethod.


  METHOD ovitemset_create_entity.

    "Variável
    DATA: ls_item TYPE zovitem.

    "Criação de um objeto para armazenar e retornar mesagens via oData.
    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    "Os dados da requisição são copiados para o er_entity.
    io_data_provider->read_entry_data(
      IMPORTING
        es_data = er_entity
    ).

    MOVE-CORRESPONDING er_entity TO ls_item.

    "Se o Id do Item não for passado ou for igual a zero.
    IF er_entity-itemid = 0.

      "Será realizado uma busca do último ID do Item referente ao ID da Ordem
      SELECT SINGLE MAX( itemid )
        INTO er_entity-itemid
        FROM zovitem
       WHERE ordemid = er_entity-ordemid.

      er_entity-itemid = er_entity-itemid + 1.

    ENDIF.

    INSERT zovitem FROM ls_item.

    IF sy-subrc IS NOT INITIAL.

      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao inserir item'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

  ENDMETHOD.


  method OVITEMSET_DELETE_ENTITY.
  endmethod.


  method OVITEMSET_GET_ENTITY.
  endmethod.


  METHOD ovitemset_get_entityset.

    "Variável
    DATA: ld_ordemid       TYPE int4.

    "Tabela Interna
    DATA: lt_ordemid_range TYPE RANGE OF int4.

    "Estruturas
    DATA: ls_ordemid_range LIKE LINE OF lt_ordemid_range,
          ls_key_tab       LIKE LINE OF it_key_tab.

    "Permite realizar uma filtragem baseado no campo primário OrdemId, onde
    "será buscados os itens que estão dentro de um cabeçalho.


    "Leitura do parâmetro da chave primária de entrada (it_key_tab)
    READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'OrdemId'.

    IF sy-subrc IS INITIAL.

      ld_ordemid = ls_key_tab-value.

      CLEAR ls_ordemid_range.

      "Utilizamos a RANGE para representar condições de filtragem, como um WHERE no banco de dados,
      "permitindo que o Gateway processe os filtros enviados na URL.

      ls_ordemid_range-sign = 'I'. "Incluir

      ls_ordemid_range-option = 'EQ'. "Igual

      ls_ordemid_range-low = ld_ordemid. "Valor

      APPEND ls_ordemid_range TO lt_ordemid_range.

    ENDIF.

    "Select para buscar os registro no banco de dados, se existir a filtragem com a OrdemId
    "será buscado os elementos conforme o filtro, se não existir a filtragem com a OrdemId
    "será buscado todos os elementos.

    SELECT *
      INTO CORRESPONDING FIELDS OF TABLE et_entityset
      FROM zovitem
     WHERE ordemid IN lt_ordemid_range.

  ENDMETHOD.


  method OVITEMSET_UPDATE_ENTITY.
  endmethod.
ENDCLASS.
