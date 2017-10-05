function [x, fval, exitflag, output] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, options)
    %INTLINPROG Mixed integer linear programming.
    %
    %   X = INTLINPROG(f,intcon,A,b) attempts to solve problems of the form
    %
    %            min f'*x    subject to:  A*x  <= b
    %             x                       Aeq*x = beq
    %                                     lb <= x <= ub
    %                                     x(i) integer, where i is in the index
    %                                     vector intcon (integer constraints)
    %
    %   X = INTLINPROG(f,intcon,A,b) solves the problem with integer variables
    %   in the intcon vector and linear inequality constraints A*x <= b. intcon
    %   is a vector of positive integers indicating components of the solution
    %   X that must be integers. For example, if you want to constrain X(2) and
    %   X(10) to be integers, set intcon to [2,10].
    %
    %   X = INTLINPROG(f,intcon,A,b,Aeq,beq) solves the problem above while
    %   additionally satisfying the equality constraints Aeq*x = beq.
    %
    %   X = INTLINPROG(f,intcon,A,b,Aeq,beq,LB,UB) defines a set of lower and
    %   upper bounds on the design variables, X, so that the solution is in the
    %   range LB <= X <= UB. Use empty matrices for LB and UB if no bounds
    %   exist. Set LB(i) = -Inf if X(i) is unbounded below; set UB(i) = Inf if
    %   X(i) is unbounded above.
    %
    %   X = INTLINPROG(f,intcon,A,b,Aeq,beq,LB,UB,OPTIONS) minimizes with the
    %   default optimization parameters replaced by values in OPTIONS, an
    %   argument created with the OPTIMOPTIONS function. See OPTIMOPTIONS for
    %   details.
    %
    %   X = INTLINPROG(PROBLEM) finds the minimum for PROBLEM. PROBLEM is a
    %   structure with the vector 'f' in PROBLEM.f, the integer constraints in
    %   PROBLEM.intcon, the linear inequality constraints in PROBLEM.Aineq and
    %   PROBLEM.bineq, the linear equality constraints in PROBLEM.Aeq and
    %   PROBLEM.beq, the lower bounds in PROBLEM.lb, the upper bounds in
    %   PROBLEM.ub, the options structure in PROBLEM.options, and solver name
    %   'intlinprog' in PROBLEM.solver.
    %
    %   [X,FVAL] = INTLINPROG(f,intcon,A,b,...) returns the value of the
    %   objective function at X: FVAL = f'*X.
    %
    %   [X,FVAL,EXITFLAG] = INTLINPROG(f,intcon,A,b,...) returns an EXITFLAG
    %   that describes the exit condition of INTLINPROG. Possible values of
    %   EXITFLAG and the corresponding exit conditions are
    %
    %     2  Solver stopped prematurely. Integer feasible point found.
    %     1  Optimal solution found.
    %     0  Solver stopped prematurely. No integer feasible point found.
    %    -2  No feasible point found.
    %    -3  Root LP problem is unbounded.
    %
    %   [X,FVAL,EXITFLAG,OUTPUT] = INTLINPROG(f,A,b,...) returns a structure
    %   OUTPUT containing information about the optimization process. OUTPUT
    %   includes the number of integer feasible points found and the final gap
    %   between internally calculated bounds on the solution. See the
    %   documentation for a complete description.
    %
    %   See also LINPROG.

    %   Copyright 2013 The MathWorks, Inc.

    % Ensure that intlinprog is passed a single structure or the correct number
    % of inputs.
    if nargin == 1

        % Single input and non-structure.
        if ~isstruct(f)
            error(message('optim:intlinprog:InputArg'));
        end

        % The following inputs need to be defined for the i_parseInputs
        % function. The remaining inputs will be defined below.
        intcon = [];
        A = [];
        b = [];

    else
        % User is passing arguments individually.
        narginchk(4, 9);
    end

    % Handle missing arguments. It would be much nicer to do have a separate
    % function to do this, but that would require a varargin in the function
    % declaration. If we were to do this, the function hints in the command
    % window/editor are "intlinprog(f, varargin)" which isn't very helpful.
    % Having the arguments defined in the function declaration means that the
    % function hints look like "intlinprog(f, intcon, A, b, Aeq, beq, lb, ub,
    % options)", which is what we want the user to see.
    if nargin < 9
        options = [];
        if nargin < 8
            ub = [];
            if nargin < 7
                lb = [];
                if nargin < 6
                    beq = [];
                    if nargin < 5
                        Aeq = [];
                    end
                end
            end
        end
    end

    % Parse inputs. Perform in a try catch to make it appear that the error is
    % returned from the top level function.
    try
        problem = i_createProblem(f, intcon, A, b, Aeq, beq, lb, ub, options);
    catch ME
        throw(ME);
    end

    % Create the algorithm from the options.
    algorithm = createAlgorithm(problem.options);

    % Check that we can run the problem.
    try
        problem = checkRun(algorithm, problem, 'intlinprog');
    catch ME
        throw(ME);
    end

    % Run the algorithm
    [x, fval, exitflag, output] = run(algorithm, problem);

    % If exitflag is {NaN, <aString>}, this means an internal error has been
    % thrown. The internal exit code is held in exitflag{2}.
    if iscell(exitflag) && isnan(exitflag{1})
        i_handleInternalError(exitflag{2});   
    end

    function ME = i_handleInternalError(internalExitCode)

    % Create the exception
    switch internalExitCode
        case '1'
            % Some matrix coefficients are NaN, which is not allowed by
            % intlinprog
            ME = MException('optim:intlinprog:CoefficientsAreNaN', ...
                getString(message('optim:intlinprog:CoefficientsAreNaN')));
        case '0'
            % Some matrix coefficients exceed the allowed limits for
            % intlinprog.
            ME = MException('optim:intlinprog:CoefficientsTooLarge', ...
                getString(message('optim:intlinprog:CoefficientsTooLarge')));        
        otherwise
            % We throw an error with an exit code that a user send to Technical
            % Support for guidance on how to address this problem.
            ME = MException('optim:intlinprog:UnknownError', ...
                getString(message('optim:intlinprog:UnknownError', internalExitCode)));        
    end

    % Throw the exception
    throwAsCaller(ME);

    function problem = i_createProblem(f, intcon, A, b, Aeq, beq, lb, ub, options)

    if isa(f,'struct')

        % Check that the problem structure contains the fields "f" and
        % "intcon". If not, we cannot proceed and we should throw an
        % informative error.
        if ~all(isfield(f, {'f', 'intcon', 'solver', 'options'}))

            % Create the doc file tags
            docFile = sprintf('%s/optim/ug/%s.html', docroot, 'intlinprog');
            [docFileTagStart, docFileTagEnd] = i_createDocFileTags(docFile);

            % Throw the error
            error(message('optim:intlinprog:ProblemMissingFields', ...
                docFileTagStart, docFileTagEnd));

        end

        % Get the individual elements of the problem structure.
        [f,intcon,A,b,Aeq,beq,lb,ub,options] = separateOptimStruct(f);

    end

    % Create a problem structure. Individually creating each field is quicker
    % than one call to struct
    problem.f = f;
    problem.intcon = intcon;
    problem.Aineq = A;
    problem.bineq = b;
    problem.Aeq = Aeq;
    problem.beq = beq;
    problem.lb = lb;
    problem.ub = ub;
    problem.options = options;
    problem.solver = 'intlinprog';

    % Create a set of options if one has not been passed to the solver.
    % All inputs will be initialized after this point.
    if isempty(problem.options)
        problem.options = optim.options.Intlinprog;
    end
    if ~isa(problem.options, 'optim.options.Intlinprog')

        % Create the doc file tags
        docFile = sprintf('%s/optim/ug/%s.html', docroot, 'set-and-change-options');
        [docFileTagStart, docFileTagEnd] = i_createDocFileTags(docFile);

        % Throw the error
        error(message('optim:intlinprog:InvalidOptions', docFileTagStart, docFileTagEnd));

    end

    function [docFileTagStart, docFileTagEnd] = i_createDocFileTags(docFile)

    % Don't add links to error/warning if running no-desktop, or deployed code, etc.
    enableLinks = feature('hotlinks') && ~isdeployed;

    % Create the hyperlink tags
    if enableLinks
        docFileTagStart = sprintf('<a href = "matlab: helpview(''%s'')">', docFile);
        docFileTagEnd = sprintf('</a>');
    else
        docFileTagStart = '';
        docFileTagEnd = '';
    end