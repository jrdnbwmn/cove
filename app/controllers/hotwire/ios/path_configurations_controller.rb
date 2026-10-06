class Hotwire::Ios::PathConfigurationsController < ApplicationController
  def show
    render json: {
      settings: {
        register_with_account: Jumpstart.config.register_with_account?,
        require_authentication: false,
        tabs: [
          {title: "Home", path: root_path, ios_system_image_name: "house"},
          {title: "What's New", path: announcements_path, ios_system_image_name: "megaphone"}
        ]
      },
      rules: [
        {patterns: ["/new$", "/edit$", "/users/sign_up", "/users/sign_in"], properties: {context: "modal"}},
        {patterns: ["^/unauthorized"], properties: {view_controller: "unauthorized"}},
        {patterns: ["^/reset_app$"], properties: {view_controller: "reset_app"}}
      ]
    }
  end
end
