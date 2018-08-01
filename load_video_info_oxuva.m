function [img_files, pos, target_sz, ground_truth, video_path] = load_video_info_oxuva(base_path, subset, video, object)
%LOAD_VIDEO_INFO
%   Loads all the relevant information for the video in the given path:
%   the list of image files (cell array of strings), initial position
%   (1x2), target size (1x2), the ground truth information for precision
%   calculations (Nx2, for N frames), and the path where the images are
%   located. The ordering of coordinates and sizes is always [y, x].
%

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
    % Select the desired task.
    is_match = (cellfun(@(x) strcmp(x, video), tasks.video_id) & ...
                cellfun(@(x) strcmp(x, object), tasks.object_id));
    if sum(is_match) ~= 1
        error('number of matches not 1: %d', sum(is_match));
    end
    task = tasks(is_match, :);

    % Construct image files.
    video_path = [fullfile(base_path, 'images', subset, video) '/'];
    img_files = arrayfun(@(i) sprintf('%06d.jpeg', i), task.init_frame:task.last_frame, ...
                         'UniformOutput', false);

    % Get size of first image.
    im_size = size(imread(fullfile(video_path, img_files{1})));
    im_size = im_size(1:2); 
    fprintf('video %s, object %s: num frames %d, image size %s\n', ...
            video, object, numel(img_files), mat2str(im_size));

    % Set initial position and size.
    target_sz = [task.ymax - task.ymin, task.xmax - task.xmin] .* im_size;
    pos = 0.5 * [task.ymax + task.ymin, task.xmax + task.xmin] .* im_size;

    % We have ground truth for the first frame only (initial position)
    ground_truth = [];

end
