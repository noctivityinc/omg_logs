# OMG Logs 🚀

**Enhanced Rails development logging that doesn't suck**

OMG Logs transforms your Rails development console from a noisy mess into a beautiful, organized, and actually useful logging experience. Say goodbye to font loading errors, ActionCable spam, and unreadable SQL queries!

## ✨ Features

- 🎯 **Method Tracing** - See exactly which methods are called during each request
- 🗄️ **Enhanced SQL Logging** - Beautiful, colorized SQL queries with performance indicators
- 🔇 **Noise Filtering** - Automatically filters out font loading errors, ActionCable spam, and other development noise
- 🎨 **Beautiful Formatting** - Colorized, structured output that's actually readable
- 📄 **Template Tracking** - See which templates and partials are rendered
- ⚡ **Performance Indicators** - Visual cues for query performance (⚡🟡🟠🔴)
- 🔧 **Highly Configurable** - Enable/disable features as needed

## 🚀 Installation

Add to your Gemfile in the development group:

```ruby
group :development do
  gem 'omg_logs'
end
```

Then run the installer:

```bash
bundle install
rails generate omg_logs:install
```

That's it! OMG Logs will automatically enhance your development logging.

## 📋 What You Get

### Before OMG Logs 😱

```
Started GET "/users" for 127.0.0.1 at 2023-11-20 10:30:45 -0500
Cannot render console from 127.0.0.1! Allowed networks: 127.0.0.0/127.255.255.255, ::1
ActionController::RoutingError (No route matches [GET] "/assets/fontawesome-webfont.woff2"):
Processing by UsersController#index as HTML
  User Load (2.3ms)  SELECT "users".* FROM "users"
  ↳ app/controllers/users_controller.rb:5:in `index'
  Rendered users/index.html.erb within layouts/application (Duration: 45.2ms | Allocations: 1847)
Completed 200 OK in 67ms (Views: 63.4ms | ActiveRecord: 2.3ms | Allocations: 2841)
Turbo::StreamsChannel#subscribe
Turbo::StreamsChannel#unsubscribe
```

### After OMG Logs 🎉

```
🚀 ================================================================================================= 🚀
GET /users (html) | UsersController#index | 200 | 67ms
View: 63.4ms | DB: 2.3ms | Allocations: 2841

Methods Called:
  → UsersController#authenticate_user (before_action)
  → UsersController#index
  → UsersController#set_current_user

Templates Rendered:
  📄 app/views/users/index.html.erb
  📄 app/views/layouts/application.html.erb

Time: 10:30:45 | IP: 127.0.0.1
─────────────────────────────────────────────────────────────────────────────────────────────────
```

### Enhanced SQL Logging

```
🚀 ================================================================================================= 🚀
📋 GET /users (html) | UsersController#index
────────────────────────────────────────────────────────────────────────────────────────────────

  ⚡ 🔍 User Load (2.3ms) SELECT "users".* FROM "users" [UsersController#index:5]
  🟡 🔍 Role Load (15.4ms) SELECT "roles".* FROM "roles" WHERE "roles"."user_id" IN (1,2,3) [User#roles:23]
  ⚡ 💰 CACHE Role Load (0.1ms) SELECT "roles".* FROM "roles" WHERE "roles"."user_id" = 1 [View: users/index.html.erb:12]
```

## ⚙️ Configuration

OMG Logs creates `config/initializers/omg_logs.rb` where you can customize everything:

```ruby
OmgLogs.configure do |config|
  # Enable/disable specific features
  config.enable_method_tracing = true
  config.enable_log_filtering = true
  config.enable_sql_logging = true
  config.enable_lograge = true
  config.enable_action_cable_filtering = true

  # Customize performance thresholds
  config.performance_thresholds = {
    fast: 5.0,      # < 5ms = ⚡
    medium: 20.0,   # 5-20ms = 🟡
    slow: 100.0     # 20-100ms = 🟠, >100ms = 🔴
  }

  # Add custom noise filters
  config.filter_patterns += [
    /your_custom_pattern/,
    /another_annoying_log/
  ]
end
```

## 📁 Log Files

OMG Logs creates separate, organized log files:

- `log/enhanced_sql.log` - Beautiful SQL queries with context
- `log/actioncable.log` - ActionCable logs (separated from main output)
- `log/sql.log` - Standard Rails SQL logs

## 🛠️ Rake Tasks

```bash
# Clear all OMG Logs files
rails omg_logs:clear

# Show current status and configuration
rails omg_logs:status

# Tail the enhanced SQL log
rails omg_logs:tail_sql
```

## 🎨 What Gets Filtered

OMG Logs automatically removes noise like:

- Font loading errors (`webfonts`, `.woff2`, `.ttf`, etc.)
- ActionCable connection spam
- Turbo Stream noise
- Web console warnings
- Asset routing errors

## 🔧 Requirements

- Rails 6.0+
- Ruby 2.7+
- Development environment only (automatically disabled in production)

## Dependencies

OMG Logs includes these awesome gems:

- `lograge` - Structured request logging
- `colorize` - Terminal colors
- `amazing_print` - Beautiful object formatting

## 🤝 Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## 📄 License

MIT License - see [MIT-LICENSE](MIT-LICENSE) file.

## 🙏 Credits

Built with ❤️ to make Rails development logging actually enjoyable!
