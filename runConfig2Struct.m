function S = runConfig2Struct(configFile)
% Executes a *script* in this function's workspace and returns its vars.
S = struct();
run(configFile);            % the script populates THIS function workspace
vars = whos();
for k = 1:numel(vars)
    name = vars(k).name;
    if ~strcmp(name,'S')
        S.(name) = eval(name);
    end
end
end