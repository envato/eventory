# Examples

## ToDo App

A ToDo app with in memory projections. It uses the eventory test database for
event storage, along with in memory projections. Events are reset each time the
app is started.

Ensure the test database has been setup by running the following in the project
root directory.

```
bin/recreate_database
```

Run the app with the following command:

```
bundle exec ruby todo.rb
```

A Pry console will start with various methods to interact with the example app.
