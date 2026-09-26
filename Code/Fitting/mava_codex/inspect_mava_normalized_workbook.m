function inventory = inspect_mava_normalized_workbook(workbook_file, output_file)
% Inspect a normalized Mava workbook before population feature extraction.
%
% The population analysis must operate on individual-cell columns, not the
% six averaged traces used in the first feature-fit screen. This helper
% records the available sheets, headers, and numeric-column counts without
% making assumptions about Control/H251N labels or data orientation.

if nargin < 1 || isempty(workbook_file)
    error('inspect_mava_normalized_workbook:missingWorkbook', ...
        'Supply the normalized individual-cell workbook path.');
end
workbook_file = char(string(workbook_file));
if ~isfile(workbook_file)
    error('inspect_mava_normalized_workbook:missingWorkbook', ...
        'Workbook not found: %s', workbook_file);
end
if nargin < 2 || isempty(output_file)
    [folder, name] = fileparts(workbook_file);
    output_file = fullfile(folder, [name '_inventory.csv']);
end

sheets = sheetnames(workbook_file);
rows = repmat(struct('sheet', "", 'n_rows', NaN, 'n_columns', NaN, ...
    'numeric_columns', NaN, 'headers', ""), numel(sheets), 1);
for i = 1:numel(sheets)
    opts = detectImportOptions(workbook_file, 'Sheet', sheets{i});
    table_data = readtable(workbook_file, opts, 'Sheet', sheets{i});
    numeric = varfun(@isnumeric, table_data, 'OutputFormat', 'uniform');
    headers = string(table_data.Properties.VariableNames);
    rows(i) = struct('sheet', string(sheets{i}), ...
        'n_rows', height(table_data), 'n_columns', width(table_data), ...
        'numeric_columns', sum(numeric), 'headers', strjoin(headers, ' | '));
end
inventory = struct2table(rows);
output_folder = fileparts(output_file);
if ~isempty(output_folder) && ~isfolder(output_folder), mkdir(output_folder); end
writetable(inventory, output_file);
end
