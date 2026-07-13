# Customizing Views

To customize views, copy the views from the Jumpstart gem into your application.

```bash
cp -R lib/jumpstart/app/views/billing/subscriptions app/views/billing/subscriptions
```

This will override the views from Jumpstart so that you won't run into git conflicts when merging future updates.

You can view the original views in `lib/jumpstart/app/views` anytime. Keep an eye on changes for these files in case instance variables or helper methods change.
