create or replace package WS is

  -- Author  : KHSADIGOV
  -- Purpose : Web Service Client

  PROCEDURE add_param(pi_params          in out varchar2,
                      pi_parameter_name  varchar2,
                      pi_parameter_value varchar2);

  FUNCTION get_param(pi_params varchar2, pi_parameter_name varchar2)
    return varchar2;

  FUNCTION get_params(pi_params varchar2) return params_array;

  PROCEDURE call(pi_template_id   VARCHAR2,
                 pi_params        VARCHAR2,
                 po_params        OUT VARCHAR2,
                 po_data_response OUT VARCHAR2);

end WS;
/
create or replace package body WS is

  PROCEDURE write_log(pi_xml_request     XMLTYPE,
                      pi_xml_response    XMLTYPE,
                      pi_request_params  VARCHAR2,
                      pi_response_params VARCHAR2,
                      pi_retval          NUMBER,
                      pi_retmsg          VARCHAR2,
                      pi_execute_time    NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO WS_LOG
      (EVENT_TIME,
       XML_REQUEST,
       XML_RESPONSE,
       REQUEST_PARAMS,
       RESPONSE_PARAMS,
       RETVAL,
       RETMSG,
       EXECUTE_TIME)
    VALUES
      (SYSTIMESTAMP,
       pi_xml_request,
       pi_xml_response,
       pi_request_params,
       pi_response_params,
       pi_retval,
       pi_retmsg,
       pi_execute_time);
    COMMIT;
  END;

  procedure add_param(pi_params          in out varchar2,
                      pi_parameter_name  varchar2,
                      pi_parameter_value varchar2) is
  begin
    pi_params := pi_params || '|' || pi_parameter_name || '={' ||
                 pi_parameter_value || '}';
  
    if substr(pi_params, 1, 1) = '|' then
      pi_params := substr(pi_params, 2);
    end if;
  end;

  FUNCTION get_param(pi_params varchar2, pi_parameter_name varchar2)
    return varchar2 is
    v_temp  varchar2(32767);
    v_start number;
    v_end   number;
  begin
  
    v_start := instr(pi_params, pi_parameter_name || '={') +
               length(pi_parameter_name || '={');
    v_end   := instr(pi_params, '}', v_start);
  
    v_temp := substr(pi_params, v_start, v_end - v_start);
  
    return v_temp;
  end;

  function get_params(pi_params varchar2) return params_array is
    v_array  params_array := params_array();
    v_params varchar2(32767) := pi_params;
    v_name   varchar2(32767);
    v_value  varchar2(32767);
  begin
    while v_params is not null and instr(v_params, '=') > 0 and
          instr(v_params, '{') > 0 and instr(v_params, '}') > 0 loop
      v_name  := substr(v_params, 1, instr(v_params, '=') - 1);
      v_value := substr(v_params,
                        instr(v_params, '={') + 2,
                        instr(v_params, '}') - length(v_name) - 3);
    
      v_array.EXTEND;
      v_array(v_array.LAST) := params_record(v_name, v_value);
    
      v_params := replace(v_params, v_name || '={' || v_value || '}');
    
      if substr(v_params, 1, 1) = '|' then
        v_params := substr(v_params, 2);
      end if;
    
    end loop;
    return v_array;
  end;

  FUNCTION generate_xml(pi_template_id VARCHAR2, pi_params VARCHAR2)
    RETURN VARCHAR2 IS
    v_template       VARCHAR2(32767);
    v_request_params VARCHAR2(32767);
    v_params         VARCHAR2(32767);
  BEGIN
    SELECT template_xml, request_params
      INTO v_template, v_request_params
      FROM ws_template
     WHERE template_id = pi_template_id
       and status = 1;
  
    if v_request_params is not null then
      v_params := v_request_params || '|' || pi_params;
    else
      v_params := pi_params;
    end if;
  
    for a in (select * from table(ws.get_params(v_params))) loop
      v_template := REPLACE(v_template,
                            '%' || upper(a.parameter_name) || '%',
                            a.parameter_value);
    end loop;
  
    RETURN v_template;
  END;

  FUNCTION generate_result(pi_template_id   VARCHAR2,
                           pi_data_response VARCHAR2) RETURN VARCHAR2 IS
    v_params          varchar2(32767);
    v_response_params varchar2(32767);
    v_path            varchar2(32767);
    v_xmlns           varchar2(32767);
    v_temp_name       varchar2(32767);
    v_temp_value      varchar2(32767);
  begin
  
    SELECT response_params, path, xmlns
      INTO v_response_params, v_path, v_xmlns
      FROM ws_template
     WHERE template_id = pi_template_id
       and status = 1;
  
    for a in (select * from table(ws.get_params(v_response_params))) loop
      v_temp_name := a.parameter_name;
    
      WITH temp_table AS
       (SELECT xmltype(pi_data_response) d FROM DUAL)
      SELECT EXTRACTVALUE(d, v_path || '/' || a.parameter_value, v_xmlns)
        into v_temp_value
        FROM temp_table;
    
      v_params := v_params || v_temp_name || '={' || v_temp_value || '}|';
    
    end loop;
  
    v_params := substr(v_params, 1, length(v_params) - 1);
  
    return v_params;
  end;

  PROCEDURE send(pi_url           IN VARCHAR2,
                 po_data_request  IN VARCHAR2,
                 po_data_response IN OUT VARCHAR2) IS
    V_SOAP_REQUEST      XMLTYPE := XMLTYPE(po_data_request);
    V_SOAP_REQUEST_TEXT CLOB := V_SOAP_REQUEST.getClobVal();
    V_REQUEST           UTL_HTTP.REQ;
    V_RESPONSE          UTL_HTTP.RESP;
    V_BUFFER            VARCHAR2(1024);
  BEGIN
    V_REQUEST := UTL_HTTP.BEGIN_REQUEST(URL => pi_url, METHOD => 'POST');
    UTL_HTTP.SET_HEADER(V_REQUEST, 'User-Agent', 'Mozilla/4.0');
    V_REQUEST.METHOD := 'POST';
    UTL_HTTP.SET_HEADER(R     => V_REQUEST,
                        NAME  => 'Content-Length',
                        VALUE => DBMS_LOB.GETLENGTH(V_SOAP_REQUEST_TEXT));
  
    UTL_HTTP.WRITE_TEXT(R => V_REQUEST, DATA => V_SOAP_REQUEST_TEXT);
  
    V_RESPONSE := UTL_HTTP.GET_RESPONSE(V_REQUEST);
  
    LOOP
      UTL_HTTP.READ_LINE(V_RESPONSE, V_BUFFER, FALSE);
    
      po_data_response := po_data_response ||
                          DBMS_XMLGEN.CONVERT(V_BUFFER, 1);
    END LOOP;
  
    UTL_HTTP.END_RESPONSE(V_RESPONSE);
  EXCEPTION
    WHEN UTL_HTTP.END_OF_BODY THEN
      UTL_HTTP.END_RESPONSE(V_RESPONSE);
    WHEN OTHERS THEN
      UTL_HTTP.END_RESPONSE(V_RESPONSE);
    
  END;

  PROCEDURE call(pi_template_id   VARCHAR2,
                 pi_params        VARCHAR2,
                 po_params        OUT VARCHAR2,
                 po_data_response OUT VARCHAR2) IS
    v_xml          VARCHAR2(32767);
    v_url          VARCHAR2(32767);
    v_retval       number;
    v_retmsg       varchar2(32767);
    v_start        TIMESTAMP;
    v_end          TIMESTAMP;
    v_execute_time NUMBER;
  BEGIN
  
    SELECT SYSTIMESTAMP INTO v_start FROM DUAL;
  
    v_xml := generate_xml(pi_template_id, pi_params);
  
    SELECT url
      INTO v_url
      FROM ws_server
     WHERE server_id = (SELECT server_id
                          FROM ws_template
                         WHERE template_id = pi_template_id)
       and status = 1;
  
    send(v_url, v_xml, po_data_response);
  
    po_params := generate_result(pi_template_id, po_data_response);
  
    SELECT SYSTIMESTAMP INTO v_end FROM DUAL;
  
    SELECT EXTRACT(MINUTE FROM diff) * 60 + EXTRACT(SECOND FROM diff) seconds
      INTO v_execute_time
      FROM (SELECT v_end - v_start diff FROM DUAL);
  
    v_retval := 1;
    v_retmsg := 'Success';
  
    write_log(xmltype(v_xml),
              xmltype(po_data_response),
              pi_params,
              po_params,
              v_retval,
              v_retmsg,
              v_execute_time);
  EXCEPTION
    WHEN OTHERS THEN
      v_retval := -1;
      v_retmsg := DBMS_UTILITY.format_error_backtrace() || SQLERRM;
      write_log(NULL,
                NULL,
                pi_params,
                po_params,
                v_retval,
                v_retmsg,
                v_execute_time);
  END;

end WS;
/
