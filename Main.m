% constant and variable
function [] = Main()
    url_list = [
        "http://seismat.local:8888/getsensor", ...
        "http://192.168.43.148:8888/getsensor", ...
        "http://172.19.203.149:8888/getsensor"
    ];

    for url = url_list
        try
            disp("Connecting to "+url);
            jsonDict = getSignals(url);
            disp("Connected");
            break;
        catch
            disp("Connection Failed");
            continue;
        end
    end

    length = numel(jsonDict);
    inputX = zeros(length, 1);
    inputY = zeros(length, 1);
    inputZ = zeros(length, 1);
    inputTime = zeros(length, 1);
    processed_inputX = zeros(length, 1);
    processed_inputY = zeros(length, 1);
    processed_inputZ = zeros(length, 1);
    sumVector_processed_input = zeros(length);
    sumVector_input = zeros(length);

    calibrate_result = recalibrate(url);
    xstart = calibrate_result(1);
    ystart = calibrate_result(2);
    zstart = calibrate_result(3);
    prev_time = datetime("now").Second;

    SeisMAT = SeisMAT_GUI_Display();
    while true

        try
            if SeisMAT.pressing == SeisMAT.display.calibrate
                disp('Pressing calibrate');
                calibrate_result = recalibrate(url);
                xstart = calibrate_result(1);
                ystart = calibrate_result(2);
                zstart = calibrate_result(3);
                SeisMAT.pressing = 0;
            end
        catch exception
            disp("error " + exception.identifier + " " + exception.message);
        end

        curr_time = datetime("now").Second;
        if (abs(curr_time - prev_time) > 0.2)
            prev_time = curr_time;
            try
                jsonDict = getSignals(url);
                length = numel(jsonDict);

                for i = 1:1:length
                    current_data = jsonDict(i);
                    inputX(i) = current_data.accelX*100 - xstart;
                    inputY(i) = current_data.accelY*100 - ystart;
                    inputZ(i) = current_data.accelZ*100 - zstart;
                    inputTime(i) = current_data.microsTimestamp/1000000;
                end

                processed_inputX = bandpass(inputX);
                processed_inputY = bandpass(inputY);
                processed_inputZ = bandpass(inputZ);

                for i = 1:1:length
                    sumVector_input(i) = sqrt(inputX(i)^2 + inputY(i)^2 + inputZ(i)^2);
                    sumVector_processed_input(i) = sqrt(processed_inputX(i)^2 + processed_inputY(i)^2 + processed_inputZ(i)^2);
                end

                SeisMAT.displayGraph('raw', inputTime, sumVector_input);
                SeisMAT.displayGraph('process', inputTime, sumVector_processed_input);

                PGA = getPGA(sumVector_processed_input, 1, length);
                xyzPGA = [getPGA(processed_inputX, 1, length) getPGA(processed_inputY, 1, length) getPGA(processed_inputZ, 1, length)];
                MMI = dec2rom(getMMI(PGA));
                JMA = shindoscale(getJMA(PGA));
                Waves = waveDetect(xyzPGA);

                SeisMAT.scaleChange('MMI', MMI);
                SeisMAT.scaleChange('PGA', PGA + " cm/s^2");
                SeisMAT.scaleChange('Shindo', JMA);
                SeisMAT.scaleChange('Wave_S', "S: "+Waves("S"));
                SeisMAT.scaleChange('Wave_P', "P: "+Waves("P"));

                SeisMAT.warning(Waves);
                
                drawnow;
            catch exception
                disp("error " + exception.identifier + " " + exception.message);
                if strcmp(exception.identifier, 'MATLAB:sys:Exit') || strcmp(exception.identifier, 'MATLAB:hg:InvalidHandle')
                    close all;
                    break;
                end
            end
        end
    end
end

% Get signals from JSON send through IP
% Input: None
% Output: Dictionary of signals
function result = getSignals(url)
    result = webread(url);
end

% Bandpass Filter Signal
% Input: Array with 1000 element contain signal
% Output: Filtered signal
function processedSignal = bandpass(inputSignal)
    Fs = 1000;

    fpass = [1 100];
    forder = 100;
    [b, ~] = fir1(forder, fpass/(Fs/2), 'band');

    processedSignal = filter(b, 1, inputSignal);
end

% Calculate Peak Ground Acceleration Value
% Input: Filtered signal, start, end
% Output: PGA
function PGA = getPGA(filteredSignal, start_point, end_point)
    PGA = max(abs(filteredSignal(start_point:end_point)));
end

% Calculate Modified Mercalli Seismic Intensity Value
% Input: PGA
% Output: MMI
function MMI = getMMI(PGA_value)
    MMI = round(2.33*log10(PGA_value) + 1.5);
end

% Calculate JMA Seismic Intensity Value
% Input: PGA
% Output: Shindo
function JMA = getJMA(PGA_value)
    JMA = 2*log10(PGA_value) + 0.94;
end

% Convert from Decimal to Roman Numeral
% Input: Decimal
% Output: Roman Numeral
function romanNumeral = dec2rom(decimalNumber)
    symbols = {'M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'};
    values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    romanNumeral = '';

    for i = 1:length(values)
        while decimalNumber >= values(i)
            romanNumeral = [romanNumeral, symbols{i}];
            decimalNumber = decimalNumber - values(i);
        end
    end
end

% Convert from JMA Decimal to Shindo Scale
% Input: JMA
% Output: Shindo
function Shindo = shindoscale(JMA)
    if JMA < 4.5
        Shindo = round(JMA);
    elseif JMA < 5
        Shindo = "5-";
    elseif JMA < 5.5
        Shindo = "5+";
    elseif JMA < 6
        Shindo = "6-";
    elseif JMA < 6.5
        Shindo = "6+";
    else
        Shindo = 7;
    end
end

% Recalibrate the sensor
% Input: url
% Output: Start point
function start = recalibrate(url)
    jsonDict = getSignals(url);
    length = numel(jsonDict);

    xstart = 0;
    ystart = 0;
    zstart = 0;

    for i = 1:1:length
        current_data = jsonDict(i);
        xstart = current_data.accelX*100 + xstart;
        ystart = current_data.accelY*100 + ystart;
        zstart = current_data.accelZ*100 + zstart;
    end

    xstart = xstart/length;
    ystart = ystart/length;
    zstart = zstart/length;

    start = [xstart, ystart, zstart];
end

% Detect Primary/Ssecondary Waves
% Input: PGA_XYZ
% Output: Waves Object
function waves = waveDetect(PGA_XYZ)
    waves = dictionary(["S" "P"], ["False" "False"]);
    if getMMI(sqrt(PGA_XYZ(2)^2 + PGA_XYZ(3)^2)) >= 5 
        waves("P") = "True";
    end
    if getMMI(PGA_XYZ(1)) >= 5 
        waves("S") = "True";
    end
end