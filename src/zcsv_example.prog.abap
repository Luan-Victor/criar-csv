*&---------------------------------------------------------------------*
*& Report ZCSV_EXAMPLE
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zcsv_example.

DATA: lt_ignoring_fields TYPE bpc_range_tab,
      lo_csv             TYPE REF TO zcl_csv,
      lt_fcat            TYPE lvc_t_fcat.

SELECTION-SCREEN: BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_csv TYPE c RADIOBUTTON GROUP rb1 DEFAULT 'X',
            p_xls TYPE c RADIOBUTTON GROUP rb1.
SELECTION-SCREEN: END OF BLOCK b1.

* Busca iregistros
SELECT * UP TO 10 ROWS
  FROM mara
  INTO TABLE @DATA(lt_mara).

* Exclui campos da estrutura
CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
  EXPORTING
    i_structure_name       = 'MARA'
  CHANGING
    ct_fieldcat            = lt_fcat
  EXCEPTIONS
    inconsistent_interface = 1
    program_error          = 2
    OTHERS                 = 3.
IF sy-subrc <> 0.
  MESSAGE 'Erro ao buscar campos da estrutura'(001) TYPE 'E'.
ENDIF.

LOOP AT lt_fcat ASSIGNING FIELD-SYMBOL(<fcat>).

  IF sy-tabix < 20.
    CONTINUE.
  ENDIF.

  APPEND INITIAL LINE TO lt_ignoring_fields ASSIGNING FIELD-SYMBOL(<ignored_field>).
  <ignored_field>-sign   = 'I'.
  <ignored_field>-option = 'EQ'.
  <ignored_field>-low    = <fcat>-fieldname.

ENDLOOP.

* Cria objeto
CREATE OBJECT lo_csv
  EXPORTING
    i_table           = lt_mara
    i_structure       = 'MARA'              " Nome da estrutura da tabela
    i_ignoring_fields = lt_ignoring_fields. " Campos da estrutura a serem ignorados

DATA(lv_filename) = 'ZCSV_EXAMPLE_' && sy-datum.

IF p_csv = abap_true.
  lo_csv->save( CHANGING i_filename = lv_filename ).
ELSE.
  lo_csv->save_as_xls( CHANGING i_filename = lv_filename ).
ENDIF.
