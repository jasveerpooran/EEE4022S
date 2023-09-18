%% Wind Resource Assessment Data Analysis
% Harnessing wind energy for power generation is a potential option to meet
% the demands of local energy markets.  This demo analyzes wind data 
% measured on a meteorological observation tower located in Massachusetts. 
% There are two wind speed sensors at 49 m, two at 38 m, and one at 20 m.  
% There are wind direction sensors at 49 m, 38 m, and 20 m.  The 
% temperature is recorded by a single sensor at 2 m.  The mean, standard
% deviation, minimum value, and maximum values of each sensor are logged
% every ten minutes from 11 am on 5/25/2007 to 4:50 pm on 6/10/2008.  
%
% Copyright 2009 - 2011 MathWorks, Inc.
%
% Written by Todd Schultz

%% Meteorological Tower Site Map
% The meteorological tower site is mapped using the Mapping Toolbox and
% Google Earth to better understand the geography at the proposed location.

% Specify location of tower
lat_base = 42.23912;    % Degrees North
lon_base = -70.85155;   % Degrees West

% Write the location to a KML file
kmlwrite('Tower_Location.kml',lat_base,lon_base, ... 
         'Description',['<BR>','Turkey Hill','<BR>','Cohasset, MA.'], ... 
         'Name','Meteorological Tower');

clear lat_base lon_base

%% 
% The map can be viewed in Google Earth.  For convenience a screenshot of
% the map in Google Earth is displayed here.  To view the map on Windows 
% with Google Earth installed use the following MATLAB command.
% >> winopen('Tower_Location.kml');

% Captured Screenshot
% Without Image Processing Toolbox
%metimage = imread('MetTower.jpg');
%image(metimage)
% With Image Processing Toolbox
%imshow('MetTower.jpg');

%% Import Data
% Start the analysis by importing the data from source, which can include
% Excel spreadsheets, text files, or even databases.  MATLAB supports the 
% supports the importing and communication with a wide range of file
% formats.  In this example, we have a data file that contains 37 columns 
% of data.  The first column is the date and the remaining columns are 
% numeric data.  We'll import all of the data into MATLAB as a dataset 
% array directly from a file. 

% An example of importing from a text file.
% Use a format string to increase file i/o performance 
wind = dataset('file','winddata.txt','delimiter','\t', ... 
               'format',['%s' repmat(' %f',1,36)]); 

% An example of importing from a database.
% Use the automatically generated MATLAB script from querybuilder to import
% the data from the Access database and convert to dataset array.
%wind = fcnImportDB;
%wind = dataset(wind);

% Initialize storage of hub velocities, instantaneous kinetic energy flux, 
% and air density in the dataset
wind.vhub = zeros(size(wind,1),1);
wind.phub = zeros(size(wind,1),1);
wind.rho = zeros(size(wind,1),1);

% Set unit property string for reminder of measurement units
wind.Properties.Units = [{'date'} repmat({'m/s'},1,4*5) ... 
                                  repmat({'deg'},1,4*3) ...
                                  repmat({'C'},1,4*1) ...
                                  'm/s' 'W/m^2' 'kg/m^3'];
                            
% Convert date to a Serial Date Number (1 = January 1, 0000 A.D.)
wind.t = datenum(wind.date,'yyyy-mm-dd HH:MM:SS');

%%
% *Input Additional Analysis Information*
% 
% Additional information about proposed wind turbine
hhub = 80;                % hub height (m)

% Additional information about meteorological tower
hv = [49 49 38 38 20];    % vector of heights for velocity (m)
hvh = [hv hhub];          % vector of heights for velocity with hhub (m)
hd = [49 38 20];          % vector of heights for direction (m)
hT = 2;                   % vector of heights for temperature (m) 

nobs = size(wind,1);      % # of observations

% Air properties
patm = 101e3;             % atmospheric pressure (Pa)
Rair = 287;               % gas constant for air (J/kg K)
% air density (kg/m^3)
wind.rho = patm./(Rair*(wind.T3Avg+273.15));

clear patm Rair

% Sensor indices
ihub = 38;                % index of hub velocity estimates
iv = 2:4:18;              % indices of velocity measurements
ivh = [iv ihub];          % indices of velocity (with hub)
id = 22:4:30;             % indices of direction measurements
iT = 34;                  % indices of temperature measurements

% Expected ranges for sensors
vrange  = [0 100];        % min and max velocity (m/s)
drange = [0 360];         % expected range for direction (deg)
Trange = [-50 150];       % expected range for temperature measurements (C)

% Critical values for Icing Test
% vAvg > vice & dSD <= dstdice & TAvg < Tice
vice = 1;              % critical value for wind speed (m/s)
dstdice = 0.5;         % critical value for the std of wind direction (deg)
Tice = 2;              % critical value for temperature (C)
% indices of sensor sets for icing tests [vAvg dSD TAvg]
iice = [ 2 23 34;
         6 23 34;
        10 27 34;
        14 27 34;
        18 31 34];
    
% Critical values for stuck wind direction sensor
% dSD<dSDstuck & diff(d)<ddelta for at least ndt consecutive time samples
dSDstuck = 0.1;        % critical value for wind direction std (deg)
ddelta = 0.1;          % critical value for wind direction difference (deg)
ndt = 6;               % min # of time sampes for stuck conidition
istuck = [22 26 30];   % indices for wind direction sensor stuck test

% Create variable to store statistical analysis results
wresults = [];       % structure variable for results

%% Visualize Data
% Plot the velocity, direction, and temperature graphs to better understand
% the data.     

% Time-series plots
figure
fcnvdttimeplot(wind)

%% Data Quality Assurance
% Check data for missing values and anomalies in the data.  With the
% dataset array, missing values will be 'filled in' with not a number (NaN)
% and will be ignored by most operations.  Some operations do require no
% missing values, such as the matrix inverse.  

%%
% *Missing date ranges*
% 
% Data is missing from 9/3/2007 17:00:00 to 10/1/2007 5:50:00 and from
% 4/15/2008 00:00:00 to 4/15/2008 16:50:00.  
wresults.missingdates = fcnmissingdates(wind.t);

%%
% *Prepare for remaining data quality tests*
% 
% Initialize storage for data quality flags
dqflag = fcnDataQuality(wind.t);
fcnPlotDataQuality(dqflag);

%%
% *Missing values*
% 
% (need to check all data columns)
I = isnan(double(wind(:,2:(length(hv)*4+length(hd)*4+length(hT)*4+1))));
mvflag = any(I,2);
nmiss = sum(sum(I));
disp([num2str(nmiss) ' missing values were found.'])
disp(' ')

% Store data quality and plot
dqflag.missingData = mvflag;
fcnPlotDataQuality(dqflag);

clear I

%%
% *Clipped velocity values*
% 
% (only check primary velocity measurements)
a = double(wind(:,iv));
vflags = a < vrange(1) | a > vrange(2);

nclip = sum(sum(vflags));
disp([num2str(nclip) ' clipped velocity values were found.'])
disp(' ')

% Issue warning if data fails test
for ii = 1:length(iv)
    if any(vflags(:,ii)) 
        txt = wind.Properties.VarNames(iv(ii));
        disp(['Velocity sensor values from ' txt{1} ' are possibly clipped.'])
        disp('Proceed with caution.')
        disp(' ')
    end
end

% Store data quality and plot
dqflag.clippedVelocity = any(vflags,2);
fcnPlotDataQuality(dqflag);

clear ii a txt

%%
% *Clipped direction values*
% 
% (only check primary direction measurements)
a = double(wind(:,id));
dflags = a < drange(1) | a > drange(2);

ndir = sum(sum(dflags));
disp([num2str(ndir) ' clipped direction values were found.'])
disp(' ')

% Issue warning if data fails test
for ii = 1:length(id)
    if any(dflags(:,ii)) 
        txt = wind.Properties.VarNames(id(ii));
        disp(['Direction sensor values from ' txt{1} ' are possibly clipped.'])
        disp('Proceed with caution.')
        disp(' ')
    end
end

% Store data quality and plot
dqflag.clippedDirection = any(dflags,2);
fcnPlotDataQuality(dqflag);

clear ii a txt

%%
% *Abnormal temperature values*
a = double(wind(:,iT));
Tmax = double(wind(:,iT+2));
Tmin = double(wind(:,iT+3));
Tflags = a < Trange(1) | a > Trange(2) | ... 
         Tmax > Trange(2) | Tmin < Trange(1);

nabT = sum(sum(Tflags));
disp([num2str(nabT) ' abnormal temperature values were found.'])
disp(' ')

% Issue warning if data fails test
for ii = 1:length(iT)
    if any(Tflags(:,ii)) 
        txt = wind.Properties.VarNames(iT(ii));
        disp(['Temperature sensor values from ' txt{1} ... 
              ' are possibly abnormal.'])
        disp('Proceed with caution.')
        disp(' ')
    end
end

% Store data quality and plot
dqflag.abnormalTemperature = any(Tflags,2);
fcnPlotDataQuality(dqflag);

clear ii a txt Tmin Tmax

%%
% *Icing conditions*
%
% Test data to ensure sensors are not affected by icing, which would result
% in extremely inaccurate values biased towards zero.  Icing is present if
% the following condition is true.  
% vAvg > vice & dSD <= dstdice & TAvg < Tice
nice = size(iice,1);            % # of ice tests to run
I = zeros(nobs,nice);

for ii = 1:nice
    a = double(wind(:,iice(ii,:)));
    I(:,ii) = a(:,1) > vice & a(:,2) <= dstdice & a(:,3) < Tice;
end

nIice = sum(sum(I));
disp([num2str(nIice) ' possible icing conditions were found.'])
disp(' ')

% Issue warning if data fails test
for ii = 1:nice
    if any(I(:,ii))
        a = wind.Properties.VarNames(iice(ii,:));
        txt = [' ' a{1} '  ' a{2} '  ' a{3}];
        disp('Possible icing condition on sensors:')
        disp(txt)
        disp(' ')
    end
end

iceflags = any(I,2);

% Store data quality and plot
dqflag.icingConditions = iceflags;
fcnPlotDataQuality(dqflag);

clear nice I ii a txt

%%
% *Stuck wind direction sensor test*
% 
% This test is to look for cases where the wind direction sensor might be
% prevented from moving due to inteference from forgien objects. The
% condition is tested by a low standard deviation and near-zero change in
% the averaged wind direction for consecutive time samples. 
% dSD<dSDstuck & diff(d)<ddelta for at least ndt consecutive time samples

ssearch = [repmat('1',1,ndt) '+'];  % search condition for stuck sensor
for ii = 1:length(hd)
    a = double(wind(:,istuck(ii)+1));       % search standard deviations
    Istd = a < dSDstuck;
    
    Idiff = zeros(nobs,1);              % search direction
    a = double(wind(:,istuck(ii)));
    Itemp = abs(diff(a)) <= ddelta;
    Idiff(1:end-1) = Itemp;             % adjust length to account for diff
    
    % Find the logical 'and' for Idiff and Istd
    stuck = Istd.*Idiff;
    
    % Now search for consecutive occurrences
    stuck = int2str(stuck)';
    [s,e] = regexp(stuck,ssearch);
    stuckflags = zeros(nobs,1);
    for jj = 1:length(s)
        stuckflags(s(jj):e(jj),ii) = 1;
    end
end

nstuck = sum(sum(stuckflags));
disp([num2str(nstuck) ' possible stuck conditions were found.'])
disp(' ')

% Issue warning if data fails test
for ii = 1:length(hd)
    if any(stuckflags(:,ii))
        a = wind.Properties.VarNames(istuck(ii));
        txt = ['Possible stuck condition on sensor ' a{1} '.'];
        disp(txt)
        disp(' ')
    end
end

% Store data quality and plot
dqflag.stuckWind = any(stuckflags,2);
fcnPlotDataQuality(dqflag);

clear stuck a Itemp Istd Idiff txt s e ii jj ndt

%% Remove Suspect Data
% At this point we must make a decision on how to handle the data that 
% failed the data quality assurance tests.  Options to consider include: 
% *Replacing the failed data with an average value of the data that passed.
% *Replacing the failed data with historic data from a similar site.
% *Removing the failed data from the dataset.
% This demonstration will proceed by removing the failed data, and thus
% limiting the analysis that follows to only the data that passed all of 
% the data quality assurance tests.  
wind = wind(dqflag.goodData,:);
npass = size(wind,1);       % # of observations that pass quality testing
perpass = npass/nobs;       % % of obervations that passed
disp([num2str(perpass*100,3) '% of the oberservation passed the data' ...
    ' quality assurance testing.'])

% Clean up workspace
clear Tflags Tice Trange dSDstuck ddelta dflags dqflag drange dstdice 
clear iceflags iice istuck missingdates nmiss perpass ssearch stuckflags 
clear vflags vice vrange hdq nobs mvflag nIice nabT nclip ndir nstuck

%% Statistical Analysis
% Now that we have completed the review of the data and eliminated suspect
% data, we are ready to investigate the data and determine the wind
% charactertics of the site.  This will include summary statistics, wind
% rose plots, and a more detailed look into specifics.  

%%
% *Data Summary*
% 
% Let's get a summary of the data.  The dataset array offers a nice
% features for that.  Also, let's replot the time-series data without the
% failed data points.  

% Summary
%summary(wind)

% Replot time-series
figure
fcnvdttimeplot(wind)

%% Hub Height Wind Velocity Estimate
% Estimate the wind velocity at hub height using a power law model fitted
% to the measured wind velocities for each time sample.  

if exist('vhubdata.mat','file')
    load vhubdata
    wind.vhub = vhub;
else
    matlabpool open 2
    vhub = zeros(npass,1);
    parfor ii = 1:npass
        % Compute instantaneous power law shear models
        cfobj = fcnpowerlaw(hv,double(wind(ii,iv)));
    
        % Compute estimate of wind speed at the wind turbine hub height
        vhub(ii) = cfobj(hhub);
    end
    save('vhubdata.mat','vhub')
    wind.vhub = vhub;
    matlabpool close
end

clear cfobj vhub

%% Compute Overall Averages
% Store overall averages (include hub height velocity with the velocity
% data)
wresults.overall.velocity = mean(double(wind(:,ivh)));
wresults.overall.direction = mean(double(wind(:,id)));
wresults.overall.temperature = mean(double(wind(:,iT)));   
        
%% Wind Speed Distribution
% Another view on the data is to compute and display the frequency the
% averaged wind speed was with in a certain range.  Let's create the wind
% speed distribution. 
vmax = max(max(double(wind(:,ivh))));

% Bin centers for histogram (m/s)
wresults.vdist.vbins = (0:1:ceil(vmax))';

vnames = wind.Properties.VarNames(ivh);
% Compute distributions for all averaged velocity data columns included the
% estimate at the hub height
for ii = 1:length(vnames)
    wresults.vdist.(vnames{ii}) = hist(wind.(vnames{ii}), ... 
                                       wresults.vdist.vbins)/npass;
    figure
        fcnvdistplot(wresults,vnames{ii})
end

clear ii vmax vnames
    
%% Wind Rose
% Create the wind rose plots where the direction represents the direction 
% the wind is blowing from. 

% Use wind_rose function from MATLAB Central with a small modification 
% regarding the meteorological angle conversion.
% (http://www.mathworks.com/matlabcentral/fileexchange/17748)
figure('color','white')
    fcnwindrose(wind.d49Avg,wind.v49Avg1,'dtype','meteo','n',16, ... 
         'labtitle','Height = 49 m, Sensor 1','lablegend','Velocity (m/s)')
figure('color','white')
    fcnwindrose(wind.d49Avg,wind.v49Avg2,'dtype','meteo','n',16, ... 
         'labtitle','Height = 49 m, Sensor 2','lablegend','Velocity (m/s)')
figure('color','white')
    fcnwindrose(wind.d38Avg,wind.v38Avg1,'dtype','meteo','n',16, ... 
         'labtitle','Height = 38 m, Sensor 1','lablegend','Velocity (m/s)')
figure('color','white')
    fcnwindrose(wind.d38Avg,wind.v38Avg2,'dtype','meteo','n',16, ... 
         'labtitle','Height = 38 m, Sensor 2','lablegend','Velocity (m/s)')
figure('color','white')
    fcnwindrose(wind.d20Avg,wind.v20Avg,'dtype','meteo','n',16, ... 
         'labtitle','Height = 20 m','lablegend','Velocity (m/s)')

%% Monthly Average Wind Speeds
% Compute and display the monthly average wind speeds for each wind speed
% sensor. 

% Find the months and years of the data
m = getMonth(wind.t);
y = getYear(wind.t);

dateGroups = unique([y m], 'rows');
dateGroups = sortrows(dateGroups,[1 2]);

% Initialize and compute monthly average
nGroups = size(dateGroups,1);
wresults.monthavg.date = datestr([dateGroups ones(nGroups,1) ... 
                                  zeros(nGroups,3)],'mmm-yy');
wresults.monthavg.data = zeros(nGroups,length(ivh));
for mm = 1:length(ivh)
    for nn = 1:nGroups
        idx = (y == dateGroups(nn,1)) & (m == dateGroups(nn,2));
        wresults.monthavg.data(nn,mm) = mean(double(wind(idx,ivh(mm))));
    end
end

clear mm nn idx m y

% Plot the results
figure
    plot(wresults.monthavg.data,'-o');
    ylabel('v_{monthly} (m/s)')
    xlim([1 nGroups])
    set(gca,'XTick',1:2:nGroups)
    set(gca,'XTickLabel',wresults.monthavg.date(1:2:nGroups,:))
    legend(wind.Properties.VarNames(ivh),'Location','Best')

clear dateGroups nGroups

%% Diurnal Average Wind Speeds
% Compute and display the diurnal average wind speeds for each wind speed
% sensor. The hourly averages will average data from the begining of the
% hour to the end, for example from 10:00 am to 10:59 am.  

% Find the list of all possible hours in which data was acquired. 
h = getHour(wind.t);
wresults.diurnal.hour = unique(h);
nh = length(wresults.diurnal.hour);

% Initialize and compute diurnal averages

wresults.diurnal.data = zeros(nh,length(ivh));

for mm = 1:length(ivh)
    for nn = 1:nh
        I = h == wresults.diurnal.hour(nn);
        wresults.diurnal.data(nn,mm) = mean(double(wind(I,ivh(mm))));
    end
end

clear h nh I mm nn

% Plot the results
figure
    plot(wresults.diurnal.hour,wresults.diurnal.data,'-o');
    ylabel('v_{diurnal} (m/s)')
    xlabel('Hour of Day')
    xlim([wresults.diurnal.hour(1) wresults.diurnal.hour(end)])
    legend(wind.Properties.VarNames(ivh),'Location','SouthWest')

%% Turbulence Intensity
% Compute the turbulence intensity for each observation and velocity 
% sensor and the distribution for each sensor.  The turbulence intensity is
% defined as the 10-minute standard deviation of the velocity divided by 
% the 10-minute average velocity. 

% Compute turbulence intensities
wresults.ti.data = double(wind(:,iv+1))./double(wind(:,iv));

% Display turbulence intensities versus wind speed for each sensor
timax = ceil(10*max(max(wresults.ti.data)))/10;
vmax = ceil(max(max(double(wind(:,iv)))));

% Visualize data
for ii = 1:length(iv)
    figure
        subplot(2,1,1);
            plot(double(wind(:,iv(ii))),wresults.ti.data(:,ii),'+')
            xlim([0 ceil(vmax)])
            ylim([0 ceil(10*timax)/10])
            box on
            %xlabel('Wind velocity (m/s)')
            ylabel('TI')
            title(['Turbulence Intensity for ' ...
                char(wind.Properties.VarNames(iv(ii)))])
        subplot(2,1,2);
            boxplot(wresults.ti.data(:,ii),round(double(wind(:,iv(ii)))))
            xlim([0 ceil(vmax)])
            xlabel('Wind velocity (m/s)')
            ylabel('TI')
end

clear ii timax vmax
        
%% Shear Profile
% Compute the shear exponent of the power law model for the atmospheric 
% boundary layer.  The power law model is of the form u = a*z^alpha.  The
% coefficient, a, and the exponent, alpha, are estimated using regression
% analysis using the data from all velocity sensors.  Remember to exclude
% the estimated velocity at hub height in the analysis of the shear or
% boundary layer profile.  

% Fit for overall data
[cfobj,cfgood] = fcnpowerlaw(hv,wresults.overall.velocity(1:length(hv)));
wresults.bl.overall.cfobj = cfobj;
wresults.bl.overall.cfgood = cfgood;
wresults.bl.overall.alpha = coeffvalues(cfobj);
wresults.bl.overall.alpha = wresults.bl.overall.alpha(2);

% Plot of overall data and fit (up to a height of 100 m)
x = logspace(-2,2,200);
y = cfobj(x);

figure
    plot(wresults.overall.velocity(1:length(hv)),hv,'o',y,x)
    xlabel('Wind velocity (m/s)')
    ylabel('Height (m)')
    legend('Data','Power Law','Location','Best')

clear x y cfobj cfgood

% Fit for monthly average wind speed
wresults.bl.monthly.date = wresults.monthavg.date;
nmonths = length(wresults.bl.monthly.date);
wresults.bl.monthly.cfobj = cell(length(nmonths),1);
wresults.bl.monthly.cfgood = cell(length(nmonths),1);
wresults.bl.monthly.alpha = zeros(length(nmonths),1);

for ii = 1:nmonths
    [cfobj,cfgood] = fcnpowerlaw(hv, ... 
                                  wresults.monthavg.data(ii,1:length(hv)));
    alpha = coeffvalues(cfobj);
    wresults.bl.monthly.cfobj{ii} = cfobj;
    wresults.bl.monthly.cfgood{ii} = cfgood;
    wresults.bl.monthly.alpha(ii) = alpha(2); 
end

clear ii cfobj cfgood alpha

% Plot monthly and overal alpha values
fcnalphaplot(1:nmonths,wresults.bl.monthly.alpha,wresults.bl.overall.alpha)
    
clear nmonths

%% Wind Power and Capacity Factor Estimate
% Compute the mean wind speed, kinetic energy flux, and the capacity factor
% using both the local, short term data and correlation to a data source
% with long term data accessible.  This report correlates the local site at
% Cohasset to the weather station at Boston Logan Internation Airport
% (KBOS).  

%%
% *Short Term Kinetic Energy Flux*
% 
% Compute the power density in the wind as measured by the meteorological
% tower.  This will represent the local, short-term power that was 
% available to any wind turbine installed at this location during the
% measurement period.  

% Compute instantaneous kinetic energy flux
wind.phub = 0.5*wind.rho.*wind.vhub.^3;

% Compute and store mean wind kinetic energy flux at hub height
wresults.overall.phub = mean(wind.phub);
% display to published report
disp(['Mean KE flux (W/m^2): ' num2str(wresults.overall.phub,'%3.0f')])
disp(' ')

% Plot instantaneous hub wind speeds and KE flux
figure
fcnKEplot(wind,ivh,wresults)

%% 
% *Short Term Average Turbine Power and Capacity Factor*
% 
% Estimate the average turbine power and capacity factor for this site 
% using the short-term estimated hub height velocity distribution.  These
% calculations require knowledge of the proposed wind turbine model and its
% power curve.  For this demo, let's assume a 1.5 MW wind turbine with a
% power curve modelled in fcnpowercurve.

% Wind turbine rated power (W)
Prated = 1500e3;
wresults.short.Prated = Prated;

% Compute Pavgshort as the integral of the wind turbine power curve and the
% pdf of the wind speed at the hub height.  
dx = mean(diff(wresults.vdist.vbins));      % integral steps (m/s)
Pavgshort = sum(fcnpowercurve(wresults.vdist.vbins,Prated).* ... 
                wresults.vdist.vhub(:))*dx;
wresults.short.Pavgshort = Pavgshort;
            
% Compute short-term capacity factor
CFshort = Pavgshort/Prated;
wresults.short.CFshort = CFshort;

% Display results
disp(['Assumed wind turbine rated power (MW): ' num2str(Prated/1e6,'%3.1f')])
disp(['Short-term averaged power (kW): ' num2str(Pavgshort/1e3,'%3.0f')])
disp(['Short-term Capacity Factor (%): ' num2str(CFshort*100,'%2.0f')])
disp(' ')

clear Prated Pavgshort dx CFshort

%% 
% *Long Term Wind Speed*
% 
% Calculate the long term using the measure-correlate-predict (MCP) method
% comparing the local Cohasset data to long term data from Boston Logan
% Internation Airport in Massachusetts.  In particular, the linear regress 
% method is used.  

% Retreive concurrent data from reference site
% This example pulls historic data from the Wunderground website at
% http://www.wunderground.com/history/airport for weather tower KBOS
% located at Boston Logan Airport.  
if exist('kbosdata.mat','file')
    load('kbosdata.mat')
else
    kbosds = fcnGrabWeatherData('KBOS',wind.date(1),wind.date(end));
end

% Create data set for regression
t = kbosds.Datenum;                % time vector (datenum)
vlongterm = kbosds.WindSpeedMS;    % wind speed at long-term location (m/s)
% Interpolate the measured data from the site under study to correspond to
% same sample times as the long-term data.
vsite = interp1(wind.t,wind.v49Avg1,t);

% Remove data from period of missing dates
md = wresults.missingdates;
I = ones(length(t),1);
for ii = 1:size(md,1)
    Itemp = ~(t >= md(ii,1) & t <= md(ii,2));
    I = I & Itemp;
end
vlongterm = vlongterm(I);
vsite = vsite(I);

% Preform regression
[cfobj,cfgood] = fcnlinear(vlongterm,vsite);
wresults.long.mcp.cfobj = cfobj;
wresults.long.mcp.cfgood = cfgood;

% Use long-term average at weather station site to estimate long-term
% average at site under consideration
%vbarlt = fcnGrabLongTermWind('KBOS',1978,2008);    % takes 3.5 m to run
vbarlt = 4.9817;

% Use regression to estimate the long-term wind speed at the site
v49barlt = cfobj(vbarlt);
wresults.long.v49barlt = v49barlt;
wresults.long.v49barltci = predint(cfobj,v49barlt,0.95);

% Estimate long-term wind speed at hub height using the overall estimate
% for the shear coefficient. 
alpha = wresults.bl.overall.alpha;
vhublt = v49barlt*(hhub/hv(1))^alpha;
wresults.long.vhublt = vhublt;

% Display results
disp(['Long-term Wind Speed at Hub Height (m/s): ' num2str(vhublt,'%3.1f')])

%% 
% *Long Term Power and Capacity Factor*
% 
% Estimate wind speed distribution at hub height for the long term average
% Note: Assume a Rayleigh distribution with parameter b, which can be
% related to the mean 
b = vhublt*sqrt(2/pi);
vbins = wresults.vdist.vbins;
vltpdf = raylpdf(vbins,b);

% Wind turbine rated power (W)
Prated = wresults.short.Prated;
wresults.long.Prated = Prated;

% Compute Pavglong as the integral of the wind turbine power curve and the
% pdf of the wind speed at the hub height.  
dx = mean(diff(wresults.vdist.vbins));      % integral steps (m/s)
Pavglong = sum(fcnpowercurve(vbins,Prated).*vltpdf)*dx;
wresults.long.Pavglong = Pavglong;
            
% Compute long-term capacity factor
CFlong = Pavglong/Prated;
wresults.long.CFlong = CFlong;

% Display results
disp(['Assumed wind turbine rated power (MW): ' num2str(Prated/1e6,'%3.1f')])
disp(['Long-term averaged power (kW): ' num2str(Pavglong/1e3,'%3.0f')])
disp(['Long-term Capacity Factor (%): ' num2str(CFlong*100,'%2.0f')])

clear ii md cfobj cfgood I Itemp vlongterm vsite t kbosds Prated
clear vbarlt v49barlt vhublt alpha Pavglong CFlong dx b vbins vltpdf

%%
clear all; close all;