function digest = mava_sha256(file)
% Return the lowercase SHA-256 digest of a file's raw bytes.

file = char(string(file));
fid = fopen(file, 'rb');
if fid < 0
    error('mava_sha256:openFailed', 'Could not open file: %s', file);
end
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');

engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
raw_digest = typecast(engine.digest(), 'uint8');
digest = lower(reshape(dec2hex(raw_digest, 2).', 1, []));
end
