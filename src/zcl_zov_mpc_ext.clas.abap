class ZCL_ZOV_MPC_EXT definition
  public
  inheriting from ZCL_ZOV_MPC
  create public .

public section.

  types:
    "Tipo do agrupamento das Entidades Ordem e Item
    BEGIN OF ty_ordem_item,
        ordemid     TYPE i,
        datacriacao TYPE timestamp,
        criadopor   TYPE c LENGTH 20,
        clienteid   TYPE i,
        totalitens  TYPE p LENGTH 8 DECIMALS 2,
        totalfrete  TYPE p LENGTH 8 DECIMALS 2,
        totalordem  TYPE p LENGTH 8 DECIMALS 2,
        status      TYPE c LENGTH 1,
        toovitem    TYPE TABLE OF ts_ovitem WITH DEFAULT KEY,
      END OF ty_ordem_item .

  methods DEFINE
    redefinition .
protected section.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_ZOV_MPC_EXT IMPLEMENTATION.


  method DEFINE.
    "Método responsável por definir manualmente os metadados da oData Service,
    "ou seja, podendo definir por exemplo um tipo complexo.

    "Criando OBJETO do tipo da entidade que irá permitir a manipulação do tipo da entidade.
    DATA lo_entity_type TYPE REF TO /iwbep/if_mgw_odata_entity_typ.

    "Chama a implementação padrão(superclasse) do método DEFINE, onde ele herda o modelo padrão
    "definido no SEGW, sem essa chamada, o modelo precisaria ser feito manualmente.
    super->define( ).

    "Chamada do método get_entity_type passando o OVCAB como nome da entidade,
    "será retornado um objeto que será atribuido ao objeto criado anteriormente,
    lo_entity_type = model->get_entity_type( iv_entity_name = 'OVCab').

    "Chamada do método bind_structure passando o tipo que foi criado para vincular a estrutura
    "TY_ORDEM_ITEM com à entidade OVCab.
    lo_entity_type->bind_structure( iv_structure_name = 'ZCL_ZOV_MPC_EXT=>TY_ORDEM_ITEM' ).

  endmethod.
ENDCLASS.
