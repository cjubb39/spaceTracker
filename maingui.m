function varargout = maingui(varargin)
% MAINGUI MATLAB code for maingui.fig
%      MAINGUI, by itself, creates a new MAINGUI or raises the existing
%      singleton*.
%
%      H = MAINGUI returns the handle to a new MAINGUI or the handle to
%      the existing singleton*.
%
%      MAINGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MAINGUI.M with the given input arguments.
%
%      MAINGUI('Property','Value',...) creates a new MAINGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before maingui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to maingui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help maingui

% Last Modified by GUIDE v2.5 01-Mar-2014 15:41:24

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

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes maingui wait for user response (see UIRESUME)
% uiwait(handles.figure1);

global targets_array;
targets = repmat(struct( ...
    'identifier', '', ...
    'name', '', ...
    'Notes', '', ...
    'Latitude', 0, ...
    'Longitude', 0, ...
    'Time', clock ...
 ), 1024, 1);
targets_array = struct('targets', targets, 'current', 0, 'count', 0);

%% Set up live update
t = timer('ExecutionMode', 'fixedRate', 'Period', 2);
t.TimerFcn = {@updatePosition, handles};
start(t);

% function for live udpating
function updatePosition(~, ~, handles)
%set global variables
ISS_POSITION_JSON_URL = 'http://api.open-notify.org/iss-now.json';
hObject = handles.liveposupdate;

% check if button is on
if (get(hObject, 'Value') == get(hObject, 'Max'))
    iss_position_json = parse_json(urlread(ISS_POSITION_JSON_URL));
    if (strcmp(iss_position_json{1}.message,'success'))
        longitude = iss_position_json{1}.iss_position.longitude;
        latitude = iss_position_json{1}.iss_position.latitude;
        
        %x = get(handles.posLat, 'String');
        set(handles.posLat, 'String', strcat({'Latitude:    '}, num2str(latitude)));
        
        %x = get(handles.posLon, 'String');
        set(handles.posLon, 'String', strcat({'Longitude:    '}, num2str(longitude)));
    end
end

function addToTargets(incoming, handles)
global targets_array;
targets_array.target(...
    targets_array.count + 1) ...
    = ...
    incoming;
targets_array.count = targets_array.count + 1;
if (targets_array.current == 0)
    targets_array.current = 1;
    updateTarget(handles);
end


% --- Outputs from this function are returned to the command line.
function varargout = maingui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in nextTarget.
function nextTarget_Callback(~, ~, handles)
% hObject    handle to nextTarget (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global targets_array;
targets_array.current = targets_array.current + 1;
if (targets_array.current > targets_array.count)
    targets_array.current = 1;
end

updateTarget(handles);


% --- Executes on button press in addtarget.
function addtarget_Callback(hObject, eventdata, handles)
% hObject    handle to addtarget (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in importtargets.
function importtargets_Callback(~, ~, handles)
% hObject    handle to importtargets (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[FileName,PathName] = uigetfile('*.xml', 'Select XML of Targets', 'targets.xml');
fullXMLpath = strcat(PathName, FileName);

%xml_targets = xmlread(fullXMLpath);
targets_struct = xml2struct(fullXMLpath);
sites_root = targets_struct.wmc__TEOSiteMgr.EOSites.wmc__TEOSite;

for i = 1:length(sites_root);
    handleXMLTarget(sites_root{i}, handles);
end

function handleXMLTarget(target, handles)
positionPattern = 'Closest approach lat: (-?\d*.?\d*), lon: (-?\d*.?\d*) at (\d{2}):(\d{2}):(\d{2})';
[match, token] = regexp(target.Attributes.Notes, positionPattern, 'match', 'tokens');

if (isempty(match))
    token = cell(1);
    token{1}(1:5) = '0';
end

curDate = clock;
addToTargets(struct( ...
    'identifier', target.Attributes.Ident, ...
    'name', target.Attributes.Nomenclature, ...
    'Notes', target.Attributes.Notes, ...
    'Latitude', token{1}(1), ...
    'Longitude', token{1}(2), ...
    'Time', datenum(curDate(1), curDate(2), curDate(3), str2double(token{1}(3)), ...
        str2double(token{1}(4)), str2double(token{1}(5))) ...
 ), handles);

function updateTarget(handles)
global targets_array;
newTarget = targets_array.target(targets_array.current);
set(handles.targetname, 'String', newTarget.name);
set(handles.targetcoord, 'String', strcat({'Lat: '}, newTarget.Latitude, ...
    {'; Lon: '}, newTarget.Longitude));
set(handles.targetCountdown, 'String', datestr(newTarget.Time, 'HH:MM:SS'));
set(handles.targetNotes, 'String', newTarget.Notes);


% --- Executes on button press in liveposupdate.
function liveposupdate_Callback(~, ~, handles)
% hObject    handle to liveposupdate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of liveposupdate
updatePosition(0,0,handles);
