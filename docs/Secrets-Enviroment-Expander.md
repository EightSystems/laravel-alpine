# Secrets Manager Environment Expander

When using Amazon ECS with Secrets Manager, as of the time of writting this document, usually you would need to:

- a) Mount each internal secret variable from your secret into a variable
- b) Mount the JSON output from your secret to a variable or file and then parse it inside your application

So, in order to help you with expanding your secrets into environment variables, we have a [run-with-secrets.php](../base/core/run-with-secrets.php) script with will do the job of reading variables or files and parsing them from json, or ini, expanding their key => values into the environment and sending it to the underlying process.

That way, you can have a simple Secrets Manager mount as JSON to a variable and let the script do the job of parsing the JSON and populating all the other variables.

All you have to do is:

- Set the environment variable `EXPAND_SECRETS_FROM_VARIABLE` with the variable name (or variables, joining them with a comma)
- And/or set the environment variable `EXPAND_SECRETS_FROM_FILE` with the file name (or files, joining them with a comma)

And it will do it's job.

To set the type of parser, you just need to add `:json` or `:ini` to the env of the name, like: `EXPAND_SECRETS_FROM_VARIABLE=variable_name_here:ini` (by default it uses json)
