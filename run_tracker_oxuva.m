%
%  Long-term Correlation Tracking v2.0
%
%  Chao Ma, 2015
%  https://sites.google.com/site/chaoma99/
%
%  Note that in this updated version, an online SVM classifier is used for
%  recovering targets and the color channels are quantized as features for
%  detector learning


function [fps, predictions] = run_tracker_oxuva(subset, video, show_visualization, show_plots)

    addpath('utility');
    addpath('detector');
    addpath('scale');

    %path to the videos (you'll be able to choose one with the GUI).
    % base_path = 'Benchmark/';
    base_path = '/home/jvlmdr/projects/2017-06-long-term/long-term-tracking-benchmark/dataset';
    %default settings
    if nargin < 2, video = 'choose'; end
    if nargin < 3, show_visualization = ~strcmp(video, 'all'); end
    if nargin < 4, show_plots = ~strcmp(video, 'all'); end


    config.padding = 1.8;  %extra area surrounding the target

    config.lambda = 1e-4;  %regularization
    config.output_sigma_factor = 0.1;  %spatial bandwidth (proportional to target)
    config.interp_factor=0.01; % best 0.01
    config.kernel_sigma = 1;

    config.features.hog_orientations = 9;
    config.features.cell_size = 4;   % size of hog grid cell
    config.features.window_size = 6; % size of local region for intensity historgram
    config.features.nbins=8; % bins of intensity historgram

    config.motion_thresh=0.15;
%     config.appearance_thresh=0.38;
    config.appearance_thresh=0.38;

    if ~iscell(video)
        if ~strcmp(video, 'all')
            error('unknown option: %s', video)
        end
        %all videos, call self with each video name.

        % Load all tasks.
        tasks = readtable(fullfile(base_path, 'tasks', [subset '.csv']), 'ReadVariableNames', false);
        tasks.Properties.VariableNames{1} = 'video_id';
        tasks.Properties.VariableNames{2} = 'object_id';
        tasks.Properties.VariableNames{3} = 'init_frame';
        tasks.Properties.VariableNames{4} = 'last_frame';
        tasks.Properties.VariableNames{5} = 'xmin';
        tasks.Properties.VariableNames{6} = 'xmax';
        tasks.Properties.VariableNames{7} = 'ymin';
        tasks.Properties.VariableNames{8} = 'ymax';
        num_tasks = size(tasks, 1);
        % Random shuffle.
        tasks = tasks(randperm(num_tasks), :);

        all_fps = zeros(numel(tasks),1);

        output_dir = 'predictions';
        if ~exist(output_dir, 'dir'), mkdir(output_dir); end

        % if ~exist('matlabpool', 'file'),
            %no parallel toolbox, use a simple 'for' to iterate
            for k = 1:size(tasks, 1),
                fprintf('task %d/%d\n', k, num_tasks);

                output_file = sprintf('%s_%s.csv', tasks.video_id{k}, tasks.object_id{k});
                output_file = fullfile(output_dir, output_file);
                if exist(output_file, 'file')
                    fprintf('skip: %s\n', output_file);
                    continue
                end

                [all_fps(k), predictions] = run_tracker_oxuva(subset, {tasks.video_id{k}, tasks.object_id{k}}, show_visualization, show_plots);
                if isempty(predictions)
                    fprintf('skip: empty\n');
                    continue
                end

                track_id = repmat({tasks.video_id{k}, tasks.object_id{k}}, size(predictions, 1), 1);
                frame_num = num2cell((tasks.init_frame(k) + 1):tasks.last_frame(k))';
                predictions = [track_id, frame_num, predictions];
                predictions = cell2table(predictions);
                writetable(predictions, output_file, 'WriteVariableNames', false);

                % Add video_id, object_id, frame_num to predictions.
                % table = cellfun(@(i) [{tasks.video_id{k}, tasks.object_id{k}, i + tasks.init_frame{k}}, ...
                %                       predictions{i}], ...
                %                 tasks{k}.init_frame:tasks{k}.last_frame, 'UniformOutput', false);
            end
        % else
        %     %evaluate trackers for all videos in parallel
        %     if matlabpool('size') == 0,
        %         matlabpool open;
        %     end
        %     parfor k = 1:numel(videos),
        %         [all_precisions(k), all_fps(k)] = run_tracker_oxuva(videos{k}, show_visualization, show_plots);
        %     end
        % end

        %compute average precision at 20px, and FPS
        fps = mean(all_fps);
        fprintf('\nAverage FPS:% 4.2f\n\n', fps)
        predictions = []


    else
        %we were given the name of a single video to process.

        %get image file names, initial state, and ground truth for evaluation
        [img_files, pos, target_sz, ground_truth, video_path] = load_video_info_oxuva(base_path, subset, video{1}, video{2});

        %call tracker function with all the relevant parameters
        [positions, time, predictions] = tracker_lct(video_path, img_files, pos, target_sz, config, show_visualization);

        %calculate and show precision plot, as well as frames-per-second
        fps = numel(img_files) / time;
        fprintf('%12s - FPS:% 4.2f\n', strjoin(video), fps)

    end
end
