Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  resources :fonts, only: [:create, :new, :show] do
    get :font_file, on: :member
  end
  root to: "fonts#new"
end
