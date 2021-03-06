function varargout = maingui(varargin)
% Main GUI for launching a tool to assist Internation Space Station
% Astronauts in finding targets and taking pictures from space.
%
% For Columbia IEME 4810: Intro to Human Spaceflight, Professor Massimino
% CJ

% Last Modified by GUIDE v2.5 14-Apr-2014 20:57:05

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @maingui_OpeningFcn, ...
                   'gui_OutputFcn',  @maingui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before maingui is made visible.
function maingui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to maingui (see VARARGIN)

% Choose default command line output for maingui
handles.output = hObject;

% set up map
axes(handles.axes2);
ax = worldmap('World');
land = shaperead('landareas', 'UseGeoCoords', true);
geoshow(ax, land, 'FaceColor', [0.5 0.7 0.5])
lakes = shaperead('worldlakes', 'UseGeoCoords', true);
geoshow(lakes, 'FaceColor', 'blue')
rivers = shaperead('worldrivers', 'UseGeoCoords', true);
geoshow(rivers, 'Color', 'blue')
handles.worldmap = ax;

global ISS_POSITION_DOT;
ISS_POSITION_DOT = geoshow(handles.axes2, 0, 0);

global TARGET_MARKER_WORLD;
TARGET_MARKER_WORLD = geoshow(handles.axes2, 10, 10);

% set up target terrian map
axes(handles.axes3);
ax2 = worldmap([-1,1],[-1,1]);
land = shaperead('landareas', 'UseGeoCoords', true);
geoshow(ax2, land, 'FaceColor', [0.5 0.7 0.5])
lakes = shaperead('worldlakes', 'UseGeoCoords', true);
geoshow(lakes, 'FaceColor', 'blue')
rivers = shaperead('worldrivers', 'UseGeoCoords', true);
geoshow(rivers, 'Color', 'blue')

global TARGET_MARKER_TER;
TARGET_MARKER_TER = geoshow(handles.axes3, 20, 20);

% Update handles structure
guidata(hObject, handles);

global targets_array;
targets = repmat(struct( ...
    'identifier', '', ...
    'name', '', ...
    'lense', '', ...
    'Notes', '', ...
    'Latitude', 0, ...
    'Longitude', 0, ...
    'Time', clock, ...
    'CloudCover', '-1' ...
 ), 1024, 1);
targets_array = struct('targets', targets, 'current', 0, 'count', 0);

%% Set up live update
t = timer('ExecutionMode', 'fixedRate', 'Period', 5);
t.TimerFcn = {@updatePosition, handles};
start(t);

t2 = timer('ExecutionMode', 'fixedRate', 'Period', 2*60);
t2.TimerFcn = @updateCC;
start(t2);

function updateCC(~, ~)
global targets_array;

for i=1:targets_array.count
    tmp = targets_array.target(i);
    tmp.CloudCover = getCurCC(tmp.Latitude, tmp.Longitude);
end

% function for live udpating
function updatePosition(~, ~, handles)
global ISS_POSITION_DOT;
%set global variables
ISS_POSITION_JSON_URL = 'http://api.open-notify.org/iss-now.json';
hObject = handles.liveposupdate;

% check if button is on
if (get(hObject, 'Value') == get(hObject, 'Max'))
    iss_position_json = parse_json(urlread(ISS_POSITION_JSON_URL));
    if (strcmp(iss_position_json{1}.message,'success'))
        longitude = iss_position_json{1}.iss_position.longitude;
        latitude = iss_position_json{1}.iss_position.latitude;
        
        set(handles.posLat, 'String', strcat({'Latitude:    '}, num2str(latitude)));
        
        set(handles.posLon, 'String', strcat({'Longitude:    '}, num2str(longitude)));
        
        %update map
        delete(ISS_POSITION_DOT);
        ISS_POSITION_DOT = geoshow(handles.axes2, latitude, longitude, ...
            'DisplayType', 'point', 'Marker', 'diamond', ...
            'MarkerFaceColor', 'red', 'MarkerSize', 10);
    end
end

function addToTargets(incoming, handles)
% add to array
global targets_array;
targets_array.target(targets_array.count + 1) = incoming;
targets_array.count = targets_array.count + 1;
targets_array.name{targets_array.count} = incoming.name;
if (targets_array.current == 0)
    targets_array.current = 1;
    updateTarget(handles);
end

set(handles.targetslist,'String',targets_array.name, 'Value', targets_array.current);


% --- Outputs from this function are returned to the command line.
function varargout = maingui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

function time = getNextISSPass(lat, lon)
iss_pass_json_url = strcat('http://api.open-notify.org/iss-pass.json?lat=', lat, '&lon=', lon, '&n=1');

% check if button is on
iss_pass_json = parse_json(urlread(iss_pass_json_url));
if (strcmp(iss_pass_json{1}.message,'success'))
    time_unixTS = iss_pass_json{1}.response{1}.risetime;
    time = datestr(time_unixTS/86400 + datenum(1970,1,1), 'mmm dd HH:MM:SS');
end

function cc = getCurCC(lat, lon)
cc_json_url = strcat('http://api.openweathermap.org/data/2.5/forecast/daily?mode=json&cnt=1&rain=f&lat=', lat, '&lon=', lon);

% check if button is on
weather_json = parse_json(urlread(cc_json_url));
cc = weather_json{1}.list{1}.clouds;

% --- Executes on button press in addtarget.
function addtarget_Callback(hObject, eventdata, handles)
% hObject    handle to addtarget (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.loadingmarker, 'String', 'LOADING...');
prompt = {'Enter Target Name:*','Target Latitude:*', 'Target Longitude:*', ...
    'Lens(es)', 'Notes:'};
dlg_title = 'Enter Custom Target!';
num_lines = [1 35;1 13;1 13;1 20;5 50];
defaultanswer = {'','','','',''};
options.Resize='on';
options.WindowStyle='modal';
options.Interpreter='tex';
retData = inputdlg(prompt, dlg_title, num_lines);

disp(retData);

name = retData{1};
lat = retData{2};
long = retData{3};
lenses = retData{4};
notes = retData{5};

addToTargets(struct( ...
    'identifier', num2str(clock), ...
    'name', name, ...
    'lense', lenses, ...
    'Notes', notes, ...
    'Latitude', lat, ...
    'Longitude', long, ...
    'Time', getNextISSPass(lat, long), ...
    'CloudCover', getCurCC(char(lat), char(long)) ...
 ), handles);

set(handles.loadingmarker, 'String', '');
    

% --- Executes on button press in importtargets.
function importtargets_Callback(~, ~, handles)
% hObject    handle to importtargets (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.loadingmarker, 'String', 'LOADING...');
[FileName,PathName] = uigetfile('*.xml', 'Select XML of Targets', 'targets.xml');
fullXMLpath = strcat(PathName, FileName);

%xml_targets = xmlread(fullXMLpath);
targets_struct = xml2struct(fullXMLpath);
sites_root = targets_struct.wmc__TEOSiteMgr.EOSites.wmc__TEOSite;

for i = 1:length(sites_root);
    handleXMLTarget(sites_root{i}, handles);
end
set(handles.loadingmarker, 'String', ' ');

function handleXMLTarget(target, handles)
positionPattern = 'Closest approach lat: (-?\d*.?\d*), lon: (-?\d*.?\d*)';
[posmatch, postoken] = regexp(target.Attributes.Notes, positionPattern, 'match', 'tokens');

if (isempty(posmatch))
    postoken = cell(1);
    postoken{1}(1:2) = '0';
end

timePattern = 'GMT: (\d{2}):(\d{2}):(\d{2})';
[timematch, timetoken] = regexp(target.Attributes.Notes, timePattern, 'match', 'tokens');

if (isempty(timematch))
    timetoken = cell(1);
    timetoken{1}(1:3) = '0';
end

lensePattern = 'Lens\(es\): (\d+.?.?)*';
[lensematch, lensetoken] = regexp(target.Attributes.Notes, lensePattern, 'match', 'tokens');

if (isempty(lensematch))
    lensetoken = cell(1);
    lensetoken{1}(1) = '0';
end

notesPattern = 'Lens([^;]*);\s*([^;]*)';
[notesmatch, notestoken] = regexp(target.Attributes.Notes, notesPattern, 'match', 'tokens');

if (isempty(notesmatch))
    notestoken = cell(1);
    notestoken{1}(1:2) = '-';
end

curDate = clock;
addToTargets(struct( ...
    'identifier', target.Attributes.Ident, ...
    'name', target.Attributes.Nomenclature, ...
    'lense', lensetoken{1}(1), ...
    'Notes', notestoken{1}(2), ...
    'Latitude', postoken{1}(1), ...
    'Longitude', postoken{1}(2), ...
    'Time', datenum(curDate(1), curDate(2), curDate(3), str2double(timetoken{1}(1)), ...
        str2double(timetoken{1}(2)), str2double(timetoken{1}(3))), ...
    'CloudCover', getCurCC(char(postoken{1}(1)), char(postoken{1}(2))) ...
 ), handles);

function updateTarget(handles)
global targets_array;
global TARGET_MARKER_WORLD;
global TARGET_MARKER_TER;
newTarget = targets_array.target(targets_array.current);
set(handles.targetname, 'String', newTarget.name);
set(handles.targetcoord, 'String', strcat({'Lat: '}, newTarget.Latitude, ...
    {'; Lon: '}, newTarget.Longitude));
set(handles.targetCountdown, 'String', datestr(newTarget.Time, 'HH:MM:SS'));
set(handles.targetNotes, 'String', newTarget.Notes);
set(handles.targetlenses, 'String', newTarget.lense);
set(handles.targetCC, 'String', strcat(num2str(newTarget.CloudCover), ' percent cloud cover'));

delete(TARGET_MARKER_WORLD);
TARGET_MARKER_WORLD = geoshow(handles.axes2, str2double(newTarget.Latitude), ...
    str2double(newTarget.Longitude), ...
    'DisplayType', 'point', 'Marker', '+', ...
    'MarkerFaceColor', 'red', 'MarkerSize', 10);

% set up map
axes(handles.axes3);
incLat = str2double(newTarget.Latitude);
incLon = str2double(newTarget.Longitude);
latLim = [incLat - 5, incLat + 5];
lonLim = [incLon - 5, incLon + 5];

ax = worldmap(latLim, lonLim);
land = shaperead('landareas', 'UseGeoCoords', true);
geoshow(ax, land, 'FaceColor', 'none')%[0.5 0.7 0.5])

layers = wmsfind('nasa.network*elev', 'SearchField', 'serverurl');
layers = wmsupdate(layers);
aster = layers(1);

cellSize = dms2degrees([0,1,0]);
[ZA, RA] = wmsread(aster, 'Latlim', latLim, 'Lonlim', lonLim, ...
   'CellSize', cellSize, 'ImageFormat', 'image/bil');
geoshow(ax, ZA, RA, 'DisplayType', 'texturemap')
demcmap(double(ZA))
colorbar

cities = shaperead('worldcities', 'UseGeoCoords', true);
geoshow(ax, cities, 'Marker', '.', 'Color', 'white')

TARGET_MARKER_TER = geoshow(handles.axes3, str2double(newTarget.Latitude), ...
    str2double(newTarget.Longitude), ...
    'DisplayType', 'point', 'Marker', 'o', ...
    'MarkerFaceColor', 'red', 'MarkerSize', 10);




% --- Executes on button press in liveposupdate.
function liveposupdate_Callback(~, ~, handles)
% hObject    handle to liveposupdate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of liveposupdate
updatePosition(0,0,handles);


% --- Executes on selection change in targetslist.
function targetslist_Callback(hObject, eventdata, handles)
% hObject    handle to targetslist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns targetslist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from targetslist
set(handles.loadingmarker, 'String', 'LOADING...');
global targets_array;
targets_array.current = get(hObject,'Value');
updateTarget(handles);
set(handles.loadingmarker, 'String', ' ');


% --- Executes during object creation, after setting all properties.
function targetslist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to targetslist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in removeCurEntry.
function removeCurEntry_Callback(hObject, eventdata, handles)
% hObject    handle to removeCurEntry (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.loadingmarker, 'String', 'LOADING...');
global targets_array;
tar_list = handles.targetslist;
cur_val = get(tar_list, 'Value');
curTarget = targets_array.target(cur_val);
cur_num_tar = targets_array.count;

% replace old junk
if (targets_array.current == targets_array.count)
    targets_array.current = targets_array.current - 1;
end
for i=cur_val:cur_num_tar - 1
    targets_array.target(i) = targets_array.target(i + 1);
end
targets_array.count = targets_array.count - 1;

% set up new name name variable for list
targets_array.name = cell(1,targets_array.count);
for i=1:targets_array.count;
   targets_array.name{i} = targets_array.target(i).name; 
end

set(handles.targetslist,'String',targets_array.name, 'Value', targets_array.current);

updateTarget(handles);
set(handles.loadingmarker, 'String', ' ');
