function tests = test_inspect_mava_normalized_workbook
tests = functiontests(localfunctions);
end

function testInspectsKnownAverageWorkbook(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
workbook = fullfile(root, 'System', 'experimental_data', 'Mava data.xlsx');
out_file = [tempname '.csv'];
cleanup = onCleanup(@() delete_if_present(out_file)); %#ok<NASGU>
inventory = inspect_mava_normalized_workbook(workbook, out_file);
verifyTrue(testCase, isfile(out_file));
verifyGreaterThanOrEqual(testCase, height(inventory), 1);
verifyGreaterThanOrEqual(testCase, inventory.numeric_columns(1), 2);
end

function delete_if_present(file_name)
if isfile(file_name), delete(file_name); end
end
