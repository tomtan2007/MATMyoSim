function test_mava_sha256
% Binary-safe hashing must match the standard SHA-256 test vector.

repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repo_root, 'Code', 'Fitting', 'mava_codex'));
fixture = [tempname '.bin'];
cleanup = onCleanup(@() delete_if_present(fixture));

fid = fopen(fixture, 'wb');
assert(fid >= 0, 'Could not create the SHA-256 fixture.');
file_cleanup = onCleanup(@() fclose(fid));
fwrite(fid, uint8('abc'), 'uint8');
clear file_cleanup;

actual = mava_sha256(fixture);
expected = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
assert(strcmp(actual, expected), ...
    'SHA-256 did not match the hand-checked standard test vector.');
assert(numel(actual) == 64 && strcmp(actual, lower(actual)), ...
    'SHA-256 must be a lowercase 64-character hexadecimal string.');

fprintf('PASS: binary-safe Mava SHA-256\n');
end

function delete_if_present(file)
if isfile(file), delete(file); end
end
