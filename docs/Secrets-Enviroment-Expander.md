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

## Writting ENV values to files

In case you need to write any of the env value to a file, you can set the `EXPAND_SECRETS_WRITE_TO_FILE` and we will take care of that to you.

Example:

```
EXPAND_SECRETS_WRITE_TO_FILE="MY_PRIVATE_KEY_IN_BASE64=/var/www/storage/app/my-private-key.pem:base64,MY_VARIABLE_IN_TEXT=/tmp/disposable-file.txt:text"
```

So, as you can see, we basically will write a file with the base64_decode contents of `MY_PRIVATE_KEY_IN_BASE64` environment variable inside the `/var/www/storage/app/my-private-key.pem`, and we also write the plain text content of `MY_VARIABLE_IN_TEXT` inside `/tmp/disposable-file.txt`

This can be handy when you have SSL keys, or some files from external providers that you need to place somewhere and you want to track them inside your secrets

### Caveats

This will only work if the place you want to write has read-write permissions to the www-data user, so, be aware that if you started your container with `read-only`, this place needs to be a `tmpdir` of some sort.

Same applies if the folder you are trying to write doesn't exists, or is owned by someone else.

TLDR: We won't create the recursive folders, nor will write if we can't write to.
