class ZCL_CSV definition
  public
  final
  create public .

public section.

  methods CONSTRUCTOR
    importing
      !I_TABLE type ANY TABLE
      !I_STRUCTURE type DD02L-TABNAME
      !I_IGNORING_FIELDS type BPC_RANGE_TAB .
  methods SAVE
    exporting
      !E_FULLPATH type STRING
      !E_PATH type STRING
    changing
      !I_FILENAME type STRING .
  methods GET
    returning
      value(E_CSV) type TRUXS_T_TEXT_DATA .
  methods SAVE_AS_XLS
    importing
      !IT_SORT type LVC_T_SORT optional
      !IT_FILT type LVC_T_FILT optional
      !IS_LAYOUT type LVC_S_LAYO optional
    changing
      !I_FILENAME type STRING .
protected section.
private section.

  data GT_CSV type TRUXS_T_TEXT_DATA .
  data GT_FCAT type LVC_T_FCAT .
  data GT_TABLE_DATA type ref to DATA .
ENDCLASS.



CLASS ZCL_CSV IMPLEMENTATION.


  METHOD constructor.

    DATA: lv_delimiter TYPE c VALUE ';',
          lv_date      TYPE char10,
          lv_time      TYPE char08.

    FIELD-SYMBOLS: <gt_table_data> TYPE STANDARD TABLE.

* Get currency for format numbers
    SELECT SINGLE mwaer
      FROM t000
      INTO @DATA(lv_currency)
      WHERE mandt = @sy-mandt.
    IF sy-subrc <> 0.
      lv_currency = 'BRL'.
    ENDIF.

* Get structure
    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name       = i_structure
      CHANGING
        ct_fieldcat            = gt_fcat
      EXCEPTIONS
        inconsistent_interface = 1
        program_error          = 2
        OTHERS                 = 3.
    IF sy-subrc <> 0.
      MESSAGE 'Erro ao buscar campos da estrutura'(001) TYPE 'E'.
    ENDIF.

* Remove some fields
    IF lines( i_ignoring_fields ) > 0.
      DELETE gt_fcat WHERE fieldname IN i_ignoring_fields.
    ENDIF.

* Create dinamic table to store input data
    cl_alv_table_create=>create_dynamic_table(
     EXPORTING
      i_style_table             = 'X'
      it_fieldcatalog           = gt_fcat
     IMPORTING
      ep_table                  = gt_table_data
     EXCEPTIONS
      generate_subpool_dir_full = 1
      OTHERS                    = 2 ).

    ASSIGN gt_table_data->* TO <gt_table_data>.
    LOOP AT i_table ASSIGNING FIELD-SYMBOL(<row>).

      APPEND INITIAL LINE TO <gt_table_data> ASSIGNING FIELD-SYMBOL(<row_data>).
      MOVE-CORRESPONDING <row> TO <row_data>.

    ENDLOOP.

* Create CSV
    CLEAR gt_csv.
    LOOP AT i_table ASSIGNING <row>.

* Header
      IF lines( gt_csv ) = 0.
        APPEND INITIAL LINE TO gt_csv ASSIGNING FIELD-SYMBOL(<csv>).
        LOOP AT gt_fcat ASSIGNING FIELD-SYMBOL(<fcat>).

          IF <csv> IS INITIAL.
            <csv> = <fcat>-scrtext_l.
          ELSE.
            <csv> = <csv> && lv_delimiter && <fcat>-scrtext_l.
          ENDIF.

        ENDLOOP.
      ENDIF.

* Items
      APPEND INITIAL LINE TO gt_csv ASSIGNING <csv>.
      LOOP AT gt_fcat ASSIGNING <fcat>.

        ASSIGN COMPONENT <fcat>-fieldname OF STRUCTURE <row> TO FIELD-SYMBOL(<field>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

* Exception example
        IF <fcat>-fieldname = 'DTEMISNC'.
          <fcat>-datatype = 'DATS'.
        ENDIF.

* Convert to currency format
        zcl_value=>to_currency_format(
          EXPORTING
            i_input    = <field>
            i_currency = lv_currency
          RECEIVING
            e_output   = DATA(lv_field)
        ).

* Convert date
        IF <fcat>-datatype = 'DATS'.
          WRITE <field> TO lv_date DD/MM/YYYY.
          lv_field = lv_date.
          TRANSLATE lv_field USING './'.
        ENDIF.

* Convert time
        IF <fcat>-datatype = 'TIMS'.
          WRITE: <field> TO lv_time.
          lv_field = lv_time.
        ENDIF.

        IF <csv> IS INITIAL.
          <csv> = lv_field.
        ELSE.
          <csv> = <csv> && lv_delimiter && lv_field.
        ENDIF.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


  METHOD get.

    e_csv = gt_csv.

  ENDMETHOD.


  METHOD save.

    IF lines( gt_csv ) > 0.

      cl_gui_frontend_services=>file_save_dialog(
        EXPORTING
          default_file_name         =  i_filename
          file_filter               =  '(*.csv)|*.csv|'
        CHANGING
          filename                  = i_filename  " File Name to Save
          path                      = e_path      " Path to File
          fullpath                  = e_fullpath  " Path + File Name
        EXCEPTIONS
          cntl_error                = 1
          error_no_gui              = 2
          not_supported_by_gui      = 3
          invalid_default_file_name = 4
          OTHERS                    = 5
      ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                   WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.

      CHECK e_path IS NOT INITIAL.

      cl_gui_frontend_services=>gui_download(
        EXPORTING
          filename                  = i_filename  " Name of file
        CHANGING
          data_tab                  = gt_csv    " Transfer table
        EXCEPTIONS
          file_write_error          = 1
          no_batch                  = 2
          gui_refuse_filetransfer   = 3
          invalid_type              = 4
          no_authority              = 5
          unknown_error             = 6
          header_not_allowed        = 7
          separator_not_allowed     = 8
          filesize_not_allowed      = 9
          header_too_long           = 10
          dp_error_create           = 11
          dp_error_send             = 12
          dp_error_write            = 13
          unknown_dp_error          = 14
          access_denied             = 15
          dp_out_of_memory          = 16
          disk_full                 = 17
          dp_timeout                = 18
          file_not_found            = 19
          dataprovider_exception    = 20
          control_flush_error       = 21
          not_supported_by_gui      = 22
          error_no_gui              = 23
          OTHERS                    = 24
      ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                   WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD SAVE_AS_XLS.

    DATA: lv_size       TYPE i,
          lt_bintab     TYPE solix_tab,
          lv_path       TYPE string,
          lv_fullpath   TYPE string.

* Get xtring from table
    cl_salv_bs_lex=>export_from_result_data_table(
          EXPORTING
            is_format            = if_salv_bs_lex_format=>mc_format_xlsx
            ir_result_data_table = cl_salv_ex_util=>factory_result_data_table(
                                                    r_data                      = gt_table_data
                                                    s_layout                    = is_layout
                                                    t_fieldcatalog              = gt_fcat
                                                    t_sort                      = it_sort
                                                    t_filter                    = it_filt )
          IMPORTING
            er_result_file       = DATA(lv_xstring) ).

* Transform to binary
    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer        = lv_xstring
      IMPORTING
        output_length = lv_size
      TABLES
        binary_tab    = lt_bintab.

* Save dialog
    cl_gui_frontend_services=>file_save_dialog(
            EXPORTING
              default_file_name         =  i_filename
              file_filter               =  cl_gui_frontend_services=>filetype_excel
            CHANGING
              filename                  = i_filename  " File Name to Save
              path                      = lv_path      " Path to File
              fullpath                  = lv_fullpath  " Path + File Name
            EXCEPTIONS
              cntl_error                = 1
              error_no_gui              = 2
              not_supported_by_gui      = 3
              invalid_default_file_name = 4
              OTHERS                    = 5
          ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

    CHECK lv_path IS NOT INITIAL.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize              = lv_size
        filename                  = i_filename  " Name of file
        filetype                  = 'BIN'
      CHANGING
        data_tab                  = lt_bintab   " Transfer table
      EXCEPTIONS
        file_write_error          = 1
        no_batch                  = 2
        gui_refuse_filetransfer   = 3
        invalid_type              = 4
        no_authority              = 5
        unknown_error             = 6
        header_not_allowed        = 7
        separator_not_allowed     = 8
        filesize_not_allowed      = 9
        header_too_long           = 10
        dp_error_create           = 11
        dp_error_send             = 12
        dp_error_write            = 13
        unknown_dp_error          = 14
        access_denied             = 15
        dp_out_of_memory          = 16
        disk_full                 = 17
        dp_timeout                = 18
        file_not_found            = 19
        dataprovider_exception    = 20
        control_flush_error       = 21
        not_supported_by_gui      = 22
        error_no_gui              = 23
        OTHERS                    = 24
    ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
