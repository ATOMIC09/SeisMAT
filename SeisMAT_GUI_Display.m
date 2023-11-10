classdef SeisMAT_GUI_Display < handle
    properties
        display
        pressing
    end

    methods
        % Function to create GUI display window
        function obj = SeisMAT_GUI_Display()
            width = 1000;
            height = 600;
            old_root = findall(0,'type','figure','name','SeisMAT');
            % Check whether root(figure) is existing or not
            if isempty(old_root) % Figure doesnt exist
                % Create Main GUI window
                obj.display.root = uifigure('name','SeisMAT','units','pixels','position',[250 100 width height], ...
                    'MenuBar','none','numbertitle','off','resize','off');
            else % Figure exist
                obj.display.root = old_root;
            end

            % Graph display panel
            obj.display.graph = uipanel(obj.display.root,'Position',[0 height*(1/3) width height*(2/3)]);

            % Scale display panel
            obj.display.status = uipanel(obj.display.root,'Position',[0 0 width height*(1/3)]);

            % Title display
            obj.display.mainTitle = uilabel(obj.display.root,'text','SeisMAT','position',[width/2-100 height-50 200 50], ...
                'fontsize',36,'HorizontalAlignment','center','FontWeight','bold');
            
            % Accelerometer Signal Display
            obj.display.raw = uiaxes(obj.display.graph,'Position',[50 50 0.4*width height/2],'FontSize',12, ...
                'XGrid','on','Ygrid','on','YLim',[-1960 1960],'YScale','linear');
            title(obj.display.raw,'Seismograph','FontSize', 16);
            
            % Processed Signal Display
            obj.display.process = uiaxes(obj.display.graph,'Position',[width/2+30 50 0.4*width height/2],'FontSize',12,...
                'XGrid','on','Ygrid','on','YLim',[-1960 1960],'YScale','linear');
            title(obj.display.process,'Bandpassed Seismograph','FontSize', 16);
            
            % Wave type display
            obj.display.wave_label = uilabel(obj.display.status,'text','Wave Type:','position',[75 130 200 30], ...
                'fontsize',24,'HorizontalAlignment','left');
            obj.display.Wave_S = uilabel(obj.display.status,'text','N/A','position',[width*(1/4) 130 150 30], ...
                'fontsize',24,'HorizontalAlignment','left');
            obj.display.Wave_P = uilabel(obj.display.status,'text','N/A','position',[width*(1/4)+100 130 150 30], ...
                'fontsize',24,'HorizontalAlignment','left');
            
            % MMI(Modified Mercalli Intensity) scale display
            obj.display.MMI_label = uilabel(obj.display.status,'text','MMI Scale:','position',[width/2+75 130 200 30], ...
                'fontsize',24,'HorizontalAlignment','left');
            obj.display.MMI = uilabel(obj.display.status,'text','N/A','position',[width*(3/4) 130 50 30], ...
                'fontsize',24,'HorizontalAlignment','left');
            
            % PGA(Peak ground Acceleration) display
            obj.display.PGA_label = uilabel(obj.display.status,'text','PGA:','position',[75 75 100 30], ...
                'fontsize',24,'HorizontalAlignment','left');
            obj.display.PGA = uilabel(obj.display.status,'text','N/A cm/s^2','position',[width/4 75 200 30], ...
                'fontsize',24,'HorizontalAlignment','left');
            
            % Shindo Scale display
            obj.display.Shindo_label = uilabel(obj.display.status,'text','Shindo Scale:','position',[width/2+75 75 200 30], ...
                'fontsize',24,'HorizontalAlignment','left');
            obj.display.Shindo = uilabel(obj.display.status,'Tag','Shindo','text','N/A','position',[width*(3/4) 75 50 30], ...
                'fontsize',24,'HorizontalAlignment','left');
            
            % Shindo Scale display
            obj.display.EW = uilabel(obj.display.root,'text','','position',[110 5 750 50], ...
                'fontsize',30,'HorizontalAlignment','center','FontColor',[1 1 1],'FontWeight','bold');

            % Recalibrate button
            obj.display.calibrate = uibutton(obj.display.root,'text','Calibrate','position',[width-90 10 80 30], ...
                'fontsize',16,'ButtonPushedFcn',@obj.btnPress);
        end
        
        % Function for recalibrate values
        function obj = btnPress(obj, src, ~)
            obj.pressing = src;
        end

        % Function for display graph
        function [] = displayGraph(obj, name, t, sum)
            graph = obj.display.(name);
            [tavg, dum] = sort(t);
            sumavg = sum(dum);
            % Plot a new line
            plot(graph, tavg(1:end-1), sumavg(1:end-1));
            set(graph, 'XLim', [min(tavg) max(tavg)])
            % Set X-axis and Y-axis label
            graph.XLabel.String = "Time(s)";
            graph.YLabel.String = "Ground Acceleration(cm/s^2)";
        end
        
        % Function for changing scale value
        function [] = scaleChange(obj, name, num)
            obj.display.(name).Text = num2str(num);
        end

        % Function for activate warning sound
        function [] = warning(obj, waves)
            Fs = 44100;
            t = 0:1/Fs:1;
            y = square(2*pi*440*t).*square(2*pi*495*t);
            if (waves("S") == "True" || waves("P") == "True")
                sound(y, Fs);
                if get(obj.display.status,'BackgroundColor') == [1 0 0]
                    set(obj.display.status,'BackgroundColor', [0.94 0.94 0.94]);
                    for member = get(obj.display.status, 'Children')
                        set(member,'FontColor', [0 0 0]);
                    end
                    set(obj.display.EW,'FontColor', [1 0 0])
                else
                    set(obj.display.status,'BackgroundColor', [1 0 0]);
                    for member = get(obj.display.status, 'Children')
                        set(member,'FontColor', [1 1 1]);
                    end
                    set(obj.display.EW,'FontColor', [1 1 1])
                end
                set(obj.display.EW,'text','WARNING! EARTHQUAKE DETECTED!');

            else
                set(obj.display.status,'BackgroundColor', [0.94 0.94 0.94]);
                for member = get(obj.display.status, 'Children')
                    set(member,'FontColor', [0 0 0]);
                end
                set(obj.display.EW,'text','');
                clear sound;
            end
        end
    end
end