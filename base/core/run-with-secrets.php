#!/usr/bin/php
<?php
/**
 * When you are running a ECS container you will notice that unless your application is aware of secrets manager, you will need to
 * a) Mount each internal secret variable from your secret into a variable
 * b) Mount the JSON output from your secret to a variable or file and then parse it inside your application
 * So I created this script that would gather these variables or files parse the JSON and expand the key => value into the environment.
 */

$variableNames = $fileNames = $writeToFiles = [];

if (isset($_SERVER['EXPAND_SECRETS_FROM_VARIABLE'])) {
    $variableNames = explode(",", $_SERVER['EXPAND_SECRETS_FROM_VARIABLE']);
}

if (isset($_SERVER['EXPAND_SECRETS_FROM_FILE'])) {
    $fileNames = explode(",", $_SERVER['EXPAND_SECRETS_FROM_FILE']);
}

if (isset($_SERVER['EXPAND_SECRETS_WRITE_TO_FILE'])) {
    $writeToFiles = explode(",", $_SERVER['EXPAND_SECRETS_WRITE_TO_FILE']);
}

if (count($variableNames) > 0) {
    printf("Loading additional env from %s\n", implode(', ', $variableNames));
} else {
    print("No EXPAND_SECRETS_FROM_VARIABLE set\n");
}

if (count($fileNames) > 0) {
    printf("Loading additional env from %s\n", implode(', ', $fileNames));
} else {
    print("No EXPAND_SECRETS_FROM_FILE set\n");
}

if (count($writeToFiles) > 0) {
    printf("Writing files from variables content from %s\n", implode(', ', $fileNames));
} else {
    print("No EXPAND_SECRETS_WRITE_TO_FILE set\n");
}

$variableContents = [];

foreach ($variableNames as $variableName) {
    $contentFormat = 'json';
    $parsedVariable = null;

    if (strpos($variableName, ':') !== false) {
        list($variableName, $contentFormat) = explode(':', $variableName, 2);
    }

    if (isset($_SERVER[$variableName])) {
        switch ($contentFormat) {
            case 'json':
                $parsedVariable = @json_decode($_SERVER[$variableName], true);
            break;
            case 'ini':
                $parsedVariable = @parse_ini_string($_SERVER[$variableName], false);
            break;
            default:
                printf('Format %s not supported', $contentFormat);
            break;
        }
    }

    if (is_array($parsedVariable)) {
        $variableContents[] = $parsedVariable;
    }
}

foreach ($fileNames as $fileName) {
    $contentFormat = 'json';
    $parsedVariable = null;

    if (strpos($fileName, ':') !== false) {
        list($fileName, $contentFormat) = explode(':', $fileName, 2);
    }

    if (file_exists($fileName)) {
        switch ($contentFormat) {
            case 'json':
                $parsedVariable = @json_decode(file_get_contents($fileName), true);
            break;
            case 'ini':
                $parsedVariable = @parse_ini_file($fileName, false);
            break;
            default:
                printf('Format %s not supported', $contentFormat);
            break;
        }
    }

    if (is_array($parsedVariable)) {
        $variableContents[] = $parsedVariable;
    }
}

foreach ($variableContents as $variableContent) {
    foreach ($variableContent as $envKey => $envValue) {
        putenv(
            sprintf('%s=%s', $envKey, $envValue)
        );

        $_SERVER[$envKey] = $envValue;
    }
}

foreach ($writeToFiles as $fileSetting) {
    $contentFormat = 'text';
    $variableName = null;
    $fileName = null;
    $parsedVariable = null;

    if (strpos($fileSetting, ':') !== false) {
        list($fileSetting, $contentFormat) = explode(':', $fileSetting, 2);
    }

    if (strpos($fileSetting, '=') !== false) {
        list($variableName, $fileName) = explode('=', $fileSetting, 2);
    } else {
        printf("Invalid setting for %s. You need to use VARIABLE=/file/name/here\n", $fileSetting);
    }

    if (! isset($_SERVER[$variableName])) {
        printf("Variable not found %s\n", $variableName);
    } else {
        $parsedVariable = $_SERVER[$variableName];
        $hasWrittenToFile = false;

        switch ($contentFormat) {
            case 'text':
                $hasWrittenToFile = @file_put_contents($fileName, $parsedVariable);
            break;
            case 'base64':
                $hasWrittenToFile = @file_put_contents($fileName, base64_decode($parsedVariable));
            break;
            default:
                printf('Format %s not supported', $contentFormat);
            break;
        }

        if ($hasWrittenToFile === false) {
            printf("Error writting to file %s. Please check permissions, if the folder folder exists, and you are not running a readonly path.\n", $fileName);
        }
    }
}

$finalCommand = implode(" ", array_map('escapeshellarg', array_slice($_SERVER['argv'], 1)));

if (! $finalCommand) {
    echo "You need to pass the command as command line argument\n";
    echo "Example: EXPAND_SECRETS_FROM_VARIABLE=hello hello=\"{\\\"world\\\": \\\"here\\\"}\" run-with-secrets.php /bin/bash\n\n";
    echo "You can use both EXPAND_SECRETS_FROM_VARIABLE and/or EXPAND_SECRETS_FROM_FILE\n\n";
    echo "You can use multiple variables, and/or multiple files, just separate them with a comma\n";
    echo "Like: EXPAND_SECRETS_FROM_VARIABLE=VARIABLE_A,VARIABLE_B,VARIABLE_C\n\n";
    echo "You can also define a format, either json (the default), or ini (which uses parse_ini_* functions)\n";
    echo "Like: EXPAND_SECRETS_FROM_VARIABLE=VARIABLE_A,VARIABLE_B:ini,VARIABLE_C:json\n";

    exit(1);
} else {
    passthru($finalCommand, $exitStatus);
    exit($exitStatus);
}
