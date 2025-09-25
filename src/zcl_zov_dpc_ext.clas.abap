class ZCL_ZOV_DPC_EXT definition
  public
  inheriting from ZCL_ZOV_DPC
  create public .

public section.

  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY
    redefinition .
  methods /IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION
    redefinition .
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


  METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.

    "Estruturas baseadas em atributos/tipos de classes.
    DATA: ls_deep_entity TYPE zcl_zov_mpc_ext=>ty_ordem_item,
          ls_deep_item   TYPE zcl_zov_mpc_ext=>ts_ovitem.

    "Tabela Interna
    DATA: lt_item        TYPE STANDARD TABLE OF zovitem.

    "Estruturas
    DATA: ls_cab  TYPE zovcab,
          ls_item TYPE zovitem.

    "Variável
    DATA: ld_updkz       TYPE char1.

    "Criação de um objeto para armazenar e retornar mesagens via oData.
    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    "Os dados da requisição são copiados para o ls_deep_entity.
    io_data_provider->read_entry_data(
      IMPORTING
        es_data = ls_deep_entity
    ).

    "Se não passarem o OrdemId.
    IF ls_deep_entity-ordemid = 0.

      ld_updkz = 'I'. "I = Insert


      MOVE-CORRESPONDING ls_deep_entity TO ls_cab.

      ls_cab-criacao_data    = sy-datum.

      ls_cab-criacao_hora    = sy-uzeit.

      ls_cab-criacao_usuario = sy-uname.

      "Seleciona o registro com o maior valor da OrdemId.
      SELECT SINGLE MAX( ordemid )
        INTO ls_cab-ordemid
        FROM zovcab.

      ls_cab-ordemid = ls_cab-ordemid + 1.

    ELSE.

      ld_updkz = 'U'. "U = Update

      SELECT SINGLE *
        INTO ls_cab
        FROM zovcab
       WHERE ordemid = ls_deep_entity-ordemid.

      ls_cab-clienteid  = ls_deep_entity-clienteid.

      ls_cab-status     = ls_deep_entity-status.

      ls_cab-totalitens = ls_deep_entity-totalitens.

      ls_cab-totalfrete = ls_deep_entity-totalfrete.

      ls_cab-totalordem = ls_deep_entity-totalordem.

    ENDIF.

    LOOP AT ls_deep_entity-toovitem INTO ls_deep_item.

      MOVE-CORRESPONDING ls_deep_item TO ls_item.

      ls_item-ordemid = ls_cab-ordemid.

      APPEND ls_item TO lt_item.

    ENDLOOP.

    IF ld_updkz = 'I'.

      "Inserção do Cabeçalho

      INSERT zovcab FROM ls_cab.

      IF sy-subrc IS NOT INITIAL.

        ROLLBACK WORK.

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

    ELSE.

      "Atualização do Cabeçalho

      MODIFY zovcab FROM ls_cab.

      IF sy-subrc IS NOT INITIAL.

        "Chama um método para armazenar a mensagem.
        lo_msg->add_message_text_only(
          EXPORTING
            iv_msg_type = 'E'
            iv_msg_text = 'Erro ao atualizar ordem'
         ).

        "Permite disparar uma exceção, ou seja, interromper o fluxo normal
        "e sinalizar que ocrreu um erro.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg.

      ENDIF.

    ENDIF.

    "Manipulação dos Itens
    DELETE FROM zovitem WHERE ordemid = ls_cab-ordemid.

    IF lines( lt_item ) > 0.

      INSERT zovitem FROM TABLE lt_item.

      IF sy-subrc IS NOT INITIAL.

        ROLLBACK WORK.

        "Chama um método para armazenar a mensagem.
        lo_msg->add_message_text_only(
          EXPORTING
            iv_msg_type = 'E'
            iv_msg_text = 'Erro ao inserir itens'
         ).

        "Permite disparar uma exceção, ou seja, interromper o fluxo normal
        "e sinalizar que ocorreu um erro.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg.

      ENDIF.

    ENDIF.

    "Atualizando o deep entity de retorno

    "Cabeçalho
    ls_deep_entity-ordemid = ls_cab-ordemid.

    CONVERT DATE ls_cab-criacao_data
            TIME ls_cab-criacao_hora
            INTO TIME STAMP ls_deep_entity-datacriacao
            TIME ZONE sy-zonlo.

    "Item.
    LOOP AT ls_deep_entity-toovitem ASSIGNING FIELD-SYMBOL(<ls_deep_item>).

      <ls_deep_item>-ordemid = ls_cab-ordemid.

    ENDLOOP.

    "Copia os dados gravados de volta para er_entity, que será retornado como resposta
    CALL METHOD me->copy_data_to_ref
      EXPORTING
        is_data = ls_deep_entity
      CHANGING
        cr_data = er_deep_entity.


  ENDMETHOD.


  METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.

    "Variáveis
    DATA: lv_ordemid TYPE zovcab-ordemid,
          lv_status  TYPE zovcab-status.

    "Tabela Interna
    DATA: lt_bapiret2 TYPE STANDARD TABLE OF zcl_zov_mpc_ext=>mensagem2.

    "Estrutura
    DATA: ls_bapiret2 TYPE zcl_zov_mpc_ext=>mensagem2.

    "Condicional para verificar qual function import será executada.
    "O parâmetro iv_action_name possui o nome de qual function import foi solicitada.
    IF iv_action_name = 'ZFI_ATUALIZA_STATUS'.

      "O parâmetro it_parameter possui os valores dos parâmetros da function import.
      lv_ordemid = it_parameter[ name = 'ID_ORDEMID' ]-value.

      lv_status  = it_parameter[ name = 'ID_STATUS' ]-value.

      UPDATE zovcab
        SET status = lv_status
       WHERE ordemid = lv_ordemid.

      IF sy-subrc IS INITIAL.

        CLEAR ls_bapiret2.

        ls_bapiret2-tipo    = 'S'.

        ls_bapiret2-mensagem = 'Status atualizado'.

        APPEND ls_bapiret2 TO lt_bapiret2.

      ELSE.

        CLEAR ls_bapiret2.

        ls_bapiret2-tipo    = 'E'.

        ls_bapiret2-mensagem = 'Erro ao atualizar status'.

        APPEND ls_bapiret2 TO lt_bapiret2.

      ENDIF.

    ENDIF.

    "Copia os dados para serem retornados como resposta da requisição.
    CALL METHOD me->copy_data_to_ref
      EXPORTING
        is_data = lt_bapiret2
      CHANGING
        cr_data = er_data.

  ENDMETHOD.


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
    "ls_cab-criacao_usuario = sy-uname.

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


  METHOD ovcabset_delete_entity.
    "Variavel
    DATA: lv_count TYPE i.

    "Estrutura
    DATA: ls_key_tab LIKE LINE OF it_key_tab.

    "Criação de um objeto para armazenar e retornar mesagens via oData.
    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'OrdemId'.

    IF sy-subrc IS NOT INITIAL.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'OrdemId não informado'
       ).

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocrreu um erro.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

    "Verifica se existem itens relacionados ao cabeçalho
    SELECT COUNT(*) FROM zovitem WHERE ordemid = @ls_key_tab-value INTO @lv_count.

    IF lv_count IS NOT INITIAL.
      "Exclusão dos Itens
      DELETE FROM zovitem WHERE ordemid = ls_key_tab-value.

      IF sy-subrc IS NOT INITIAL.

        ROLLBACK WORK.

        "Chama um método para armazenar a mensagem.
        lo_msg->add_message_text_only(
          EXPORTING
            iv_msg_type = 'E'
            iv_msg_text = 'Erro ao remover itens'
         ).

        "Permite disparar uma exceção, ou seja, interromper o fluxo normal
        "e sinalizar que ocrreu um erro.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            message_container = lo_msg.

      ENDIF.
    ENDIF.

    "Exclusão do cabeçalho

    DELETE FROM zovcab WHERE ordemid = ls_key_tab-value.

    IF sy-subrc IS NOT INITIAL.

      ROLLBACK WORK.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao remover cabeçalho'
       ).

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocrreu um erro.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

    COMMIT WORK AND WAIT.

  ENDMETHOD.


  METHOD ovcabset_get_entity.

    "Variável
    DATA: ld_ordemid TYPE zovcab-ordemid.

    "Estruturas
    DATA: ls_key_tab LIKE LINE OF it_key_tab,
          ls_cab     TYPE zovcab.

    "Criação de um objeto para armazenar e retornar mesagens via oData.
    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    "Leitura do parâmetro da chave primária de entrada (it_key_tab)
    READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'OrdemId'.

    IF sy-subrc IS NOT INITIAL.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Id da ordem não informado'
      ).

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocrreu um erro.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

    ld_ordemid = ls_key_tab-value.

    SELECT SINGLE * INTO ls_cab FROM zovcab WHERE ordemid = ld_ordemid.

    IF sy-subrc IS INITIAL.

      MOVE-CORRESPONDING ls_cab TO er_entity.

      "Pelo nome dos campos serem diferentes, o move-corresponding não será efetivo,
      "por isso é necessário atribuir manualmente
      er_entity-criadopor = ls_cab-criacao_usuario.

      "Pelo ls_cab trabalhar com o campo data e hora enquanto o entity-set trabalha com TIMESTAMP,
      "é necessário realizar essa conversão de data e hora para TIMESTAMP.
      CONVERT
        DATE ls_cab-criacao_data
        TIME ls_cab-criacao_hora
        INTO TIME STAMP er_entity-datacriacao
        TIME ZONE sy-zonlo.

    ELSE.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Id da ordem não encontrado'
      ).

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocrreu um erro.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

  ENDMETHOD.


  METHOD ovcabset_get_entityset.

    "Tabelas Internas

    DATA: lt_cab       TYPE STANDARD TABLE OF zovcab,
          lt_orderby   TYPE STANDARD TABLE OF string.

    "Estruturas

    DATA: ls_cab       TYPE zovcab.

    "Variável
    DATA: ld_orderby  TYPE string.

    "et_entityset é o parâmetro que serve para retornar a lista de registros solicitados.
    "Estrutura responsável em manipular o et_entityset.
    DATA: ls_entityset LIKE LINE OF et_entityset.

    "it_order é o parâmetro responsável em armazenar a ordenação da requisição URI.
    "Loop responsável em tratar alguns campos do it_order.
    LOOP AT it_order INTO DATA(ls_order).

      TRANSLATE ls_order-property TO UPPER CASE.

      IF ls_order-property EQ 'DATACRIACAO'.

        ls_order-property = 'CRIACAO_DATA'.

      ELSEIF ls_order-property EQ 'CRIADOPOR'.

        ls_order-property = 'CRIACAO_USUARIO'.

      ENDIF.

      TRANSLATE ls_order-order TO UPPER CASE.

      IF ls_order-order = 'DESC'.

        ls_order-order = 'DESCENDING'.

      ELSE.

        ls_order-order = 'ASCENDING'.

      ENDIF.

      APPEND |{ ls_order-property } { ls_order-order } | TO lt_orderby.

   ENDLOOP.

   "Concatena todas as linhas que vierem do loop em uma única variável.
   CONCATENATE LINES OF lt_orderby INTO ld_orderby SEPARATED BY ''.

   "Ordenação obrigatório caso nenhma seja definida (Evitar o erro do OFFSET)

   IF ld_orderby IS INITIAL.

     ld_orderby = 'OrdemId ASCENDING'.

   ENDIF.

    "O parâmetro iv_filter_string possui as informações do que será filtrado
    "na requisição oData.

    "O parâmetro is_paging-top possui as informações sobre a paginição na
    "requisição oData.

    "O parâmetro is_paging-top possui as informações do limite do número máximo de linhas
    "e o comando UP TO ROWS realiza essa limitação.

    "O parâmetro is_paging-skip possui as informações de quantas linhas serão puladas
    "e o comando OFFSER realiza esse pulo de linha.
    SELECT * FROM zovcab
      WHERE (iv_filter_string)
       ORDER BY (ld_orderby)
      INTO TABLE @lt_cab
        UP TO @is_paging-top ROWS
      OFFSET @is_paging-skip.

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


  METHOD ovcabset_update_entity.

    "Variável
    DATA: lv_error TYPE flag.

    "Criação de um objeto para armazenar e retornar mesagens via oData.
    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    "Os dados da requisição são copiados para o er_entity.
    io_data_provider->read_entry_data(
      IMPORTING
        es_data = er_entity
    ).

    "Atribuição do campo chave OrdemId para o campo da entidade
    er_entity-ordemid = it_key_tab[ name = 'OrdemId' ]-value.

    "Validações
    IF er_entity-clienteid = 0.

      lv_error = 'X'.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Cliente vazio'
       ).

    ENDIF.

    IF er_entity-totalordem < 10.

      lv_error = 'X'.

      "Chama um método para armazenar a mensagem
      lo_msg->add_message(
        EXPORTING
          iv_msg_type   = 'E'
          iv_msg_id     = 'ZOV'
          iv_msg_number = 1
          iv_msg_v1     = 'R$ 10,00'
          iv_msg_v2     = |{ er_entity-ordemid }|
      ).

    ENDIF.

    IF lv_error = 'X'.

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocorreu um erro.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg
          http_status_code  = 400.

    ENDIF.

    UPDATE zovcab
      SET  clienteid  = er_entity-clienteid
           totalitens = er_entity-totalitens
           totalfrete = er_entity-totalfrete
           totalordem = er_entity-totalordem
           status     = er_entity-status
     WHERE ordemid    = er_entity-ordemid.

    IF sy-subrc IS NOT INITIAL.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao atualizar ordem'
       ).

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocorreu um erro.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.
    ENDIF.

  ENDMETHOD.


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


  METHOD ovitemset_delete_entity.

    "Estruturas
    DATA: ls_item    TYPE zovitem,
          ls_key_tab LIKE LINE OF it_key_tab.

    "Criação de um objeto para armazenar e retornar mesagens via oData.
    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    ls_item-ordemid = it_key_tab[ name = 'OrdemId' ]-value.

    ls_item-itemid  = it_key_tab[ name = 'ItemId' ]-value.

    DELETE FROM zovitem
      WHERE ordemid = ls_item-ordemid
        AND itemid  = ls_item-itemid.

    IF sy-subrc IS NOT INITIAL.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao remover item'
       ).

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocrreu um erro.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

  ENDMETHOD.


  METHOD ovitemset_get_entity.

    "Estruturas
    DATA: ls_key_tab LIKE LINE OF it_key_tab,
          ls_item    TYPE zovitem.

    "Variável
    DATA: ld_error   TYPE flag.

    "Criação de um objeto para armazenar e retornar mesagens via oData.
    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    "Leitura do parâmetro da chave primária OrdemId (it_key_tab)
    READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'OrdemId'.

    IF sy-subrc IS NOT INITIAL.

      ld_error = 'X'.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Id da ordem não informado'
      ).

    ENDIF.

    ls_item-ordemid = ls_key_tab-value.

    "Leitura do parâmetro da chave primária ItemId (it_key_tab)
    READ TABLE it_key_tab INTO ls_key_tab WITH KEY name = 'ItemId'.

    IF sy-subrc IS NOT INITIAL.

      ld_error = 'X'.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Id do item não informado'
      ).

    ENDIF.

    ls_item-itemid = ls_key_tab-value.

    IF ld_error = 'X'.

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocrreu um erro.

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

    SELECT SINGLE * INTO ls_item FROM zovitem
      WHERE ordemid = ls_item-ordemid
        AND itemid  = ls_item-itemid.

    IF sy-subrc IS INITIAL.

      MOVE-CORRESPONDING ls_item TO er_entity.

    ELSE.

      "Chama um método para armazenar a mensagem.
      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Item não encontrado'
      ).

      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

  ENDMETHOD.


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


  METHOD ovitemset_update_entity.

    "Criação de um objeto para armazenar e retornar mesagens via oData.
    DATA(lo_msg) = me->/iwbep/if_mgw_conv_srv_runtime~get_message_container( ).

    "Os dados da requisição são copiados para o er_entity.
    io_data_provider->read_entry_data(
      IMPORTING
        es_data = er_entity
    ).

    "Atribuição de campos que podem não ser preenchidos no URI
    er_entity-ordemid  = it_key_tab[ name = 'OrdemId' ]-value.

    er_entity-itemid   = it_key_tab[ name = 'ItemId' ]-value.

    er_entity-precotot = er_entity-quantidade * er_entity-precouni.

    UPDATE zovitem
      SET material   = er_entity-material
          descricao  = er_entity-descricao
          quantidade = er_entity-quantidade
          precouni   = er_entity-precouni
          precotot   = er_entity-precotot
    WHERE ordemid    = er_entity-ordemid
      AND itemid     = er_entity-itemid.

    IF sy-subrc IS NOT INITIAL.

      lo_msg->add_message_text_only(
        EXPORTING
          iv_msg_type = 'E'
          iv_msg_text = 'Erro ao atualizar item'
      ).

      "Permite disparar uma exceção, ou seja, interromper o fluxo normal
      "e sinalizar que ocrreu um erro.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          message_container = lo_msg.

    ENDIF.

  ENDMETHOD.
ENDCLASS.
