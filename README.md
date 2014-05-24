WS
==

PL/SQL solution for working with Web Services

Instruction(In Russian):
http://habrahabr.ru/post/223405/



Столкнулся с требованием отправлять и получать SOAP сообщения из базы данных Oracle. 
Также это решение должно быть универсальным и легко интегрируемым с другими модулями. 
В интернете ни чего подобного не нашел. Есть статьи рассказывающие о том как посылать SOAP сообщения исползуя UTL_HTTP пакет, но ни чего более.

Решил написать универсальный продукт на PL/SQL для отправки SOAP сообщений из базы данных Oracle который легко настраивается и интегрируется.

<habracut text="Читать далее" />

Итак, приступим. 

Данное решение исползует следующие обьекты Базы Данных:
<ul>
       <li>User-Defined Datatypes </li>
       <li> Table</li>
       <li> Package</li>
</ul>


Предполагается что читателю не нужно объяснять что такое SOAP, XML или объекты Базы Данных Oracle. 

<h4>Установка</h4>
Для установки данного решения необходимо  установить следующие объекты                                                                                                                                                                                                          

<ul>
	<li>Тип PARAMS_RECORD </li>
	<li>Тип PARAMS_ARRAY </li>
	<li>Таблица WS_SERVER </li>
	<li>Таблица WS_TEMPLATE </li>
	<li>Таблица WS_LOG </li>
	<li>Пакет WS </li>
</ul>
<a href="https://github.com/KhayyamSadigov/WS">Исходный код</a>

<h4>Инструкции</h4>
Рассмотрим структуру таблиц

<img src="http://habrastorage.org/getpro/habr/post_images/822/94f/63c/82294f63cd765210c0d20de6fd5e6e8b.png" alt="image"/>

Рассмотрим каждую из них более подробно

<h6>Таблица WS_SERVER</h6>
Хранит список Серверов куда будут отправлятся SOAP/XML сообщения.

Столбец SERVER_ID – Логический идентификатор сервера. Является Primary Key
Столбец URL – Путь к сервису  
STATUS  – Статус. 1 – работает. 0 – выключен. По умолчанию 1

<h6>Таблица WS_TEMPLATE </h6>
Хранит шаблоны и конфигурационную информацию SOAP/XML сообщений.

   TEMPLATE_ID – Логический идентификатор Шаблона. Является Primary Key
   TEMPLATE_XML – Шаблона (Формат будет рассмотрен далее)
   SERVER_ID – Логический идентификатор сервера. Является Foreign Key ссылающийся на таблицу WS_SERVER
   REQUEST_PARAMS – Параметры запроса (Формат будет рассмотрен далее)
   RESPONSE_PARAMS – Параметры ответа (Формат будет рассмотрен далее)
   XMLNS – Пространство имён
   PATH – XML Путь (Будет рассмотрен подробнее на примере далее)
   STATUS – Статус. 1 – работает. 0 – выключен. По умолчанию 1

<h6>Таблица WS_LOG  </h6>
Хранит логи об операциях.

   EVENT_TIME – Время операции
   XML_REQUEST – XML/SOAP запрос
   XML_RESPONSE – XML/SOAP ответ
   REQUEST_PARAMS – Параметры запроса
   RESPONSE_PARAMS – Параметры ответа
   RETVAL – Информация о статусе выполненного Запроса. Удачно если >0
   RETMSG – Информация о выполненном Запросе. Код ошибки в случае неудачного выполнения Запроса
   EXECUTE_TIME – Время в секундах и милисекундах потраченное на выполнение Запроса

<h6>Как заполнять Шаблон TEMPLATE_XML</h6>
Сюда вписывается сам XML файл при этом заменив необходимые для ввода параметры в следующем формате <code>%PARAMETER_NAME%</code>

Например :
<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/stock">
  <m:GetStockPrice>
    <m:StockName>%NAME%</m:StockName>
  </m:GetStockPrice>
</soap:Body>
</soap:Envelope>
</source>

В данном случае чтобы отправить данный запрос нам нужно записать в эту колонку значение в таком формате. Программа сама далее заменить это на саоотвествующий из Параметра(о параметрах говорится далее).

<source lang="xml">
<m:StockName>%NAME%</m:StockName>
</source>

Если соответственно Значений несколько ни чего не мешает их тут же указать:

<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/stock">
  <m:GetStockPrice>
    <m:StockName>%NAME%</m:StockName>
    <m:StockCount>%COUNT%</m:StockCount>
  </m:GetStockPrice>
</soap:Body>
</soap:Envelope>
</source>

Как видно указаны 2 переменные <code>NAME</code> и <code>COUNT</code>

<source lang="xml">
<m:StockName>%NAME%</m:StockName>
<m:StockCount>%COUNT%</m:StockCount>
</source>

<h6>Правило заполнения Параметров (Столбцы REQUEST_PARAMS и RESPONSE_PARAMS )</h6>
Данный столбец заполняется в следующем формате.
<code>PARAMETER_NAME_1={VALUE_1}|PARAMETER_NAME_2={VALUE_2}|…PARAMETER_NAME_N={VALUE_N}</code>

<h6>Параметр Запроса (Столбец REQUEST_PARAMS)</h6>
Данный столбец заполняется в том случае если в не зависимости от запроса есть константные переменные. В основном его можно оставить пустым. Данное значение задается при запуске основной процедуры. Об этом чуть далее.


<h6>Столбец PATH</h6>
Чтобы настроить работу с Ответом от сервера должен быть заполнен столбец PATH который указывает на путь где в XML (между какими тагами) хронится необходимый ответ.

При отправке SOAP/XML сообщения заранее известно возможный ответ который придет от сервера.
Например ответом может быть следующий SOAP/XML

<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/stock">
  <m:GetStockPriceResponse>
    <m:Price>34.5</m:Price>
  </m:GetStockPriceResponse>
</soap:Body>
</soap:Envelope>
</source>

В данном случае столбец PATH нужно записать как :
<code>/soap:Envelope/soap:Body/m:GetStockPriceResponse</code>

Как видно из Ответа именно в этом пути находится необходимое значение 
<source lang="xml">
<m:Price>34.5</m:Price>
</source>

<h6>Параметр Ответа (Столбец RESPONSE_PARAMS)</h6>
Даный Столбец обязателен для заполнения. Формат остается тот же (указанный выше).

Зная заранее формат ответа, необходимо записать в этот столбец параметры.

<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/stock">
  <m:GetStockPriceResponse>
    <m:Price>34.5</m:Price>
  </m:GetStockPriceResponse>
</soap:Body>
</soap:Envelope>
</source>

Уже указав в столбце PATH необходимый нам путь вписываем сюда необходимые значения в след формате:
<code>RESULT_PRICE={m:Price}</code>

Это означает переменной RESULT_PRICE присвоить занчение <code>m:Price</code> полученного из SOAP/XML Ответа. Далее на примере это будет подробнее рассмотрено.

<h6>Столбец XMLNS</h6>
Этот столбец пространств имен. Заполняется анологично из Запроса SOAP/XML.

<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/stock">
  <m:GetStockPrice>
    <m:StockName>%NAME%</m:StockName>
<m:StockCount>%COUNT%</m:StockCount>
  </m:GetStockPrice>
</soap:Body>
</soap:Envelope>
</source>

Этот столбец нужно заполнить вписав туда все <code>xmlns</code> из этого запроса. Из данного примера его нужно заполнить следующим значением:
<code>xmlns:soap="http://www.w3.org/2001/12/soap-envelope" xmlns:m="http://www.example.org/stock" </code>

<h6>Запуск процедуры</h6>
Теперь рассмотрим Структуру пакета и правила запуска.
Спецификация пакета следующая:

<source lang="sql">
create or replace package WS is

PROCEDURE add_param(pi_params          in out varchar2,
                      pi_parameter_name  varchar2,
                      pi_parameter_value varchar2);

  FUNCTION get_param(pi_params varchar2, pi_parameter_name varchar2)
    return varchar2;

  PROCEDURE call(pi_template_id   VARCHAR2,
                 pi_params        VARCHAR2,
                 po_params        OUT VARCHAR2,
                 po_data_response OUT VARCHAR2);

end WS;
</source>

Рассмотрим каждую функцию подробнее. 
Использование каждой из них на примере будет рассмотрено в разделе Интеграция.

<h6>Процедура add_param </h6>
Используется для добавления/формирования параметра.

Параметры
pi_params – Переменная строки параметров
pi_parameter_name – Имя добавляемого параметра 
pi_parameter_value – Значение добавляемого параметра

<h6>Функция get_param </h6>
Используется для извлечения параметра из строки параметров.

Параметры
pi_params – Переменная строки параметров
pi_parameter_name - Имя извлекаемого параметра

<h6>Процедура call </h6>
Является главной и запускает сам процесс.

Параметры
pi_template_id – Идентификатор шаблона из таблицы WS_TEMPLATE
pi_params - Переменная строки параметров необходимая для отправки
po_params - Переменная строки параметров полученная в ответ от сервера
po_data_response – XML ответ от сервера(Эту переменную можно и не использовать)

В следующем разделе будет на примере рассмотрено использование процедур пакета.

<h4>Интеграция</h4>
В это разделе мы рассмотрим интеграцию данного решения на примере выдуманного проекта.

Предположим есть Задача: 

Построить Интерфейс для взаимодействия с Сервером для конечного пользователя который должен иметь возможность производить следующие операции
<ul>
	<li> Получении информации о Товаре</li>
	<li> Добавить Товар</li>
</ul>

Схема реализации следующая:
<img src="http://habrastorage.org/getpro/habr/post_images/38c/874/1c9/38c8741c9b94680916a26ef9802ab84c.jpg"/>

Отмечу что Интерфейс между Конечным пользователем и Базой Данных может быть любым. Конечный пользователь может запускать процедуру непосредственно через SQL или же она может вызываться Сторонним приложением (Например Java IE или Java EE).

Предоставлена следующая информация:

Сам Web Service 
<code>http://10.10.1.100:8080/GoodsManagementWS/Goods</code>

Следует отметить что перед отправкой SOAP/XML сообщений на сервер, последний необходимо добавить в ACL. Для этого необходимо обратиться к Администратору Базы Данных. Так же в интерне есть информация об этом. Думаю не стоит это рассматривать в данной статье.

<h5>Примеры Запросов</h5>
<h6>Информация о товаре</h6>
Запрос:
<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/goods">
  <m:GetInfo>
    <m:ID>1</m:ID>
  </m: GetInfo >
</soap:Body>
</soap:Envelope>
</source>

Ответ:
<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/goods">
  <m:Response>
    <m:Name>Printer</m:Name>
    <m:Vendor>HP</m:Vendor>
    <m:Price>Printer</m:Price>
    <m:Count>Printer</m:Count>
  </m:Response>
</soap:Body>
</soap:Envelope>
</source>

<h6>Добавление Товара</h6>
Запрос:
<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/goods">
  <m:Add>
    <m:Name>Printer</m:Name>
    <m:Vendor>HP</m:Vendor>
    <m:Price>Printer</m:Price>
    <m:Count>Printer</m:Count>
  </m: Add >
</soap:Body>
</soap:Envelope>
</source>

Ответ:
<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/goods">
  <m:Response>
    <m:id>1</m:id>
  </m:Response>
</soap:Body>
</soap:Envelope>
</source>

Мы получили необходимые данные от заказчика. Приступаем к настройке и интеграции.

В первую очередь необходимо записать инофрмацию о сервере:

<source lang="sql">
INSERT INTO WS_SERVER (SERVER_ID, URL, STATUS)
     VALUES ('Store', 'http://10.10.1.100:8080/GoodsManagementWS/Goods', 1);
</source>

Далее необходимо записать информацию о шаблонах запросов в таблицу <code>WS_TEMPLATE</code>

<h6>Информация о товаре</h6>
<source lang="sql">
INSERT INTO WS_TEMPLATE
  (TEMPLATE_ID,
   TEMPLATE_XML,
   SERVER_ID,
   REQUEST_PARAMS,
   RESPONSE_PARAMS,
   XMLNS,
   PATH,
   STATUS)
VALUES
  ('GetInfo', --TEMPLATE_ID
   '<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/goods">
  <m:GetInfo>
    <m:ID>%ID%</m:ID>
  </m: GetInfo >
</soap:Body>
</soap:Envelope>
', --TEMPLATE_XML
   'Store', --SERVER_ID
   NULL, --REQUEST_PARAMS
   'NAME={m:Name}|VENDOR={m:Vendor}|PRICE={m:Price}|COUNT={m:Count}', --RESPONSE_PARAMS
   'xmlns:soap="http://www.w3.org/2001/12/soap-envelope" xmlns:m="http://www.example.org/goods"', --XMLNS
   '/soap:Envelope/soap:Body/m:Response', --PATH
   1) ;--STATUS
</source>

<h6>Добавление Товара</h6>
<source lang="sql">
INSERT INTO WS_TEMPLATE
  (TEMPLATE_ID,
   TEMPLATE_XML,
   SERVER_ID,
   REQUEST_PARAMS,
   RESPONSE_PARAMS,
   XMLNS,
   PATH,
   STATUS)
VALUES
  ('GetInfo', --TEMPLATE_ID
   '<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/goods">
  <m:Add>
    <m:Name>%NAME%</m:Name>
    <m:Vendor>%VENDOR%</m:Vendor>
    <m:Price>%PRICE%</m:Price>
    <m:Count>%COUNT%</m:Count>
  </m: Add >
</soap:Body>
</soap:Envelope>
', --TEMPLATE_XML
   'Store', --SERVER_ID
   NULL, --REQUEST_PARAMS
   'ID={m:id}', --RESPONSE_PARAMS
   'xmlns:soap="http://www.w3.org/2001/12/soap-envelope" xmlns:m="http://www.example.org/goods"', --XMLNS
   '/soap:Envelope/soap:Body/m:Response', --PATH
   1); --STATUS
</source>

И вот добавив всю необходимую Информацию Процедура может быть запущена. Но для этого необходимо написать процедуры для данного проекта которые в свою очередь использует процедуры из пакета WS.

<h6>Получении информации о товаре</h6>
Для этой задачи итоговая процедура будет выглядеть следующим образом

<source lang="sql">
CREATE OR REPLACE PROCEDURE GET_INFO(PI_ID     VARCHAR2,
                   PO_NAME   OUT VARCHAR2,
                   PO_VENDOR OUT VARCHAR2,
                   PO_PRICE  OUT NUMBER,
                   PO_COUNT  OUT NUMBER) IS
  v_template_id     VARCHAR2(100) := 'GetInfo';
  v_data_response   VARCHAR2(4000);
  v_request_params  VARCHAR2(4000);
  v_response_params VARCHAR2(4000);
BEGIN

-- Формирования строки параметров необходимой для отправки --
  ws.add_param(v_request_params, 'ID', PI_ID);

-- Вызов основной процедуры --
  ws.call(v_template_id,
          v_request_params,
          v_response_params,
          v_data_response);

-- Извлечение необходимых параметров из результирующей строки параметров --
  PO_NAME   := ws.get_param(v_response_params, 'NAME');
  PO_VENDOR := ws.get_param(v_response_params, 'VENDOR');
  PO_PRICE  := ws.get_param(v_response_params, 'PRICE');
  PO_COUNT  := ws.get_param(v_response_params, 'COUNT');

END;
</source>

Пакет подготовит SOAP сообщение для отправки, отправит, получит результат и в результате результирующим ответом работы итоговой процедуры будет значения полученные работой процедуры get_param. Можно получить любой параметр из списка параметров RESPONSE_PARAMS и вернуть в качестве результата.

<h6>Добавление товара</h6>
Для этой задачи итоговая процедура будет выглядеть следующим образом

<source lang="sql">
PROCEDURE GET_INFO(PI_NAME   VARCHAR2,
                   PI_VENDOR VARCHAR2,
                   PI_PRICE  NUMBER,
                   PI_COUNT  NUMBER,
                   PO_ID     OUT VARCHAR2) IS
  v_template_id     VARCHAR2(100) := 'GetInfo';
  v_data_response   VARCHAR2(4000);
  v_request_params  VARCHAR2(4000);
  v_response_params VARCHAR2(4000);
BEGIN

-- Формирования строки параметров необходимой для отправки --
  ws.add_param(v_request_params, 'NAME', PI_NAME);
  ws.add_param(v_request_params, 'VENDOR', PI_VENDOR);
  ws.add_param(v_request_params, 'PRICE', PI_PRICE);
  ws.add_param(v_request_params, 'COUNT', PI_COUNT);

-- Вызов основной процедуры --
  ws.call(v_template_id,
          v_request_params,
          v_response_params,
          v_data_response);

-- Извлечение необходимого параметра из результирующей строки параметров --
  PO_ID := ws.get_param(v_response_params, 'ID');

END;
</source>

В этой процедуре уже входных параметров несколько, а результирующая переменная одна.

И так, в итоге получились 2 процедуры которые выполняют поставленную задачу. Результаты запросов логируются в таблицу <code>WS_LOG</code>


<h4>Дополнительные вопросы</h4>

<h6>Что если необходимые данные в ответе находятся в разных путях ? </h6>
<source lang="xml">
<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/goods">
  <m:Response1>
    <m:id>1</m:id>
  </m:Response1>
  <m:Response2>
    <m:id>1</m:id>
  </m:Response2>
  <m:Response3>
    <m:id>1</m:id>
  </m:Response3>
</soap:Body>
</soap:Envelope>
</source>

В таком случае PATH записывает <code>как /soap:Envelope/soap:Body</code>. Так как необходимый ответ находится между тагами  <code><soap:Body> и </soap:Body></code>. А уже RESPONSE_PARAMS нужно будет записать немного детальней.

<code>ID1={m:Response1/m:id}| ID2={m:Response2/m:id}| ID3={m:Response3/m:id}</code>

<h6>Что если SOAP/XML Запрос и Ответ простейшие ?</h6>
Запрос
<source lang="xml">
<Request>
    <Data>Test</Data>
</Request>
</source>

Ответ
<source lang="xml">
<Response>
   <Result>DONE</Result>
<Response>
</source>

В таком случае все настраивается аналагичным образом. 
Соответственно XMLNS пустой, PATH равен <code>Response </code>и RESPONSE_PARAMS равен <code>RES={Result}</code>. Отмечу что имя переменной указывается произвольно, но именно оно будет использоватся для запроса в процедре <code>get_param</code>

<h6>Если я ввожу строку REQUEST_PARAMS во время запуска процедры, то зачем нужен столбец REQUEST_PARAMS в таблице WS_TEMPLATE ?</h6>
Надобность в данном столбце возникает в том случае если в Запросе SOAP/XML есть значения которые не изменны. Указав их в данном столбце во время запуска процедуры уже нет надобности добавлять эти параметры(процедура add_param) так как они уже добавлены по умолчанию.


Вот и все. 

Старался выложить достаточно информации. 
Буду рад услышать и ответить на вопросы которые возникнут. А также критику, предложения и советы. 
Решение было написано недавно. Так что есть вещи которые можно доработать.

Спасибо. Надеюсь статья оказалась полезной.
