# README

## About the project

An application representing a "Apu Library" — a personal online collection of movies, books, and other art objects.

## Technology

Ruby on Rails, GraphQL, React

## Steps

### Create rails project

```
rails new apu-library --skip-action-mailbox --skip-action-text --skip-spring --webpack=react -T --skip-turbolinks
```

### Disable unnecesssary generators in the config/application.rb:

```
config.generators do |g|
  g.test_framework  false
  g.stylesheets     false
  g.javascripts     false
  g.helper          false
  g.channel         assets: false
end
```

### Generate data models (Item, User)

```
rails g model User first_name last_name email
rails g model Item title description:text image_url user:references
```

#### Add the has_many :items association to app/models/user.rb:

```
# app/models/user.rb
class User < ApplicationRecord
  has_many :items, dependent: :destroy
end
```

#### Add some pre-generated data to db/seeds.rb:

```
# db/seeds.rb
john = User.create!(
  email: "john.doe@example.com",
  first_name: "John",
  last_name: "Doe"
)

jane = User.create!(
  email: "jane.doe@example.com",
  first_name: "Jane",
  last_name: "Doe"
)

Item.create!(
  [
    {
      title: "Martian Chronicles",
      description: "Cult book by Ray Bradbury",
      user: john,
      image_url: "https://upload.wikimedia.org/wikipedia/en/4/45/The-Martian-Chronicles.jpg"
    },
    {
      title: "The Martian",
      description: "Novel by Andy Weir about an astronaut stranded on Mars trying to survive",
      user: john,
      image_url: "https://upload.wikimedia.org/wikipedia/en/c/c3/The_Martian_2014.jpg"
    },
    {
      title: "Doom",
      description: "A group of Marines is sent to the red planet via an ancient " \
                   "Martian portal called the Ark to deal with an outbreak of a mutagenic virus",
      user: jane,
      image_url: "https://upload.wikimedia.org/wikipedia/en/5/57/Doom_cover_art.jpg"
    },
    {
      title: "Mars Attacks!",
      description: "Earth is invaded by Martians with unbeatable weapons and a cruel sense of humor",
      user: jane,
      image_url: "https://upload.wikimedia.org/wikipedia/en/b/bd/Mars_attacks_ver1.jpg"
    }
  ]
)
```

### Initialize database

```
rails db:create db:migrate db:seed
```

### Add GraphQL endpoint

```
bundle add graphql
rails g graphql:install
bundle install
```

### Create type classes (ItemType, UserType)

```
rails g graphql:object item
rails g graphql:object user
```

### Install the Apollo framework for dealing with GraphQL client-side

```
yarn add apollo-client apollo-cache-inmemory apollo-link-http apollo-link-error apollo-link graphql graphql-tag react-apollo
```

### Generate a controller to serve the frontend application

```
rails g controller Library index --skip-routes
```

### Configure Apollo

Create a file for storing application's Apollo config:

```
mkdir -p app/javascript/utils && touch app/javascript/utils/apollo.js
```

```
// app/javascript/utils/apollo.js

// client
import { ApolloClient } from 'apollo-client';
// cache
import { InMemoryCache } from 'apollo-cache-inmemory';
// links
import { HttpLink } from 'apollo-link-http';
import { onError } from 'apollo-link-error';
import { ApolloLink, Observable } from 'apollo-link';
export const createCache = () => {
  const cache = new InMemoryCache();
  if (process.env.NODE_ENV === 'development') {
    window.secretVariableToStoreCache = cache;
  }
  return cache;
};
```

Update app/javascript/utils/apollo.js for creating Apollo client instance and handling cache, log errors, etc.

### Use a provider pattern to pass the client instances to React components

```
mkdir -p app/javascript/components/Provider && touch app/javascript/components/Provider/index.js
```

### Create a Library component to display the list of items on the page

```
mkdir -p app/javascript/components/Library && touch app/javascript/components/Library/index.js
```

### Add the component to the main page

```
// app/javascript/packs/index.js
import React from 'react';
import { render } from 'react-dom';
import Provider from '../components/Provider';
import Library from '../components/Library';

render(
  <Provider>
    <Library />
  </Provider>,
  document.querySelector('#root')
);
```

### Install and configure RSpec, or more precisely, the rspec-rails gem

```
bundle add rspec-rails --group="development,test"
rails g rspec:install
```

#### To make it easier to generate data for tests install factory_bot:
```
bundle add factory_bot_rails --group="development,test"
```

Make factory methods (create, build, etc.) globally visible in tests by adding config.include FactoryBot::Syntax::Methods to the rails_helper.rb

Since we created our models before adding Factory Bot, we should generate our factories manually. Create a single file, spec/factories.rb, for that:

```
# spec/factories.rb
FactoryBot.define do
  factory :user do
    # Use sequence to make sure that the value is unique
    sequence(:email) { |n| "user-#{n}@example.com" }
  end

  factory :item do
    sequence(:title) { |n| "item-#{n}" }
    user
  end
end
```

#### Create a spec file for QueryType:

```
mkdir -p spec/graphql/types
touch spec/graphql/types/query_type_spec.rb
```
A simple query test -

```
# spec/graphql/types/query_type_spec.rb
require "rails_helper"

RSpec.describe Types::QueryType do
  describe "items" do
    let!(:items) { create_pair(:item) }

    let(:query) do
      %(query {
        items {
          title
        }
      })
    end

    subject(:result) do
      ApuLibrarySchema.execute(query).as_json
    end

    it "returns all items" do
      expect(result.dig("data", "items")).to match_array(
        items.map { |item| { "title" => item.title } }
      )
    end
  end
end
```

### Avoid N+1 queries

The easiest way to avoid N+1 queries is to use eager loading. In our case, we need to preload users when making a query to fetch items in QueryType:

```
# /app/graphql/types/query_type.rb
module Types
  class QueryType < Types::BaseObject
    # ...

    def items
      Item.preload(:user)
    end
  end
end
```

### Implementing real-time updates

It would be great for us to have the list updated when we (users) add a new item or change an existing item. GraphQL subscriptions take care of it.

Subscription is a mechanism for delivering server-initiated updates to the client. For this Rails application, we can use ActionCable for transport.

#### Laying the cable

First, we should create app/graphql/types/subscription_type.rb and register the subscription, which is going to be triggered when the new item is added.

```
# app/graphql/types/subscription_type.rb

module Types
  class SubscriptionType < GraphQL::Schema::Object
    field :item_added, Types::ItemType, null: false, description: "An item was added"

    def item_added; end
  end
end
```

Second, we should configure our schema to use ActionCableSubscriptions and look for the available subscriptions in the SubscriptionType:

```
# app/graphql/apu_library_schema.rb

class ApuLibrarySchema < GraphQL::Schema
  use GraphQL::Subscriptions::ActionCableSubscriptions

  mutation(Types::MutationType)
  query(Types::QueryType)
  subscription(Types::SubscriptionType)
end
```

Third, we should generate an ActionCable channel for handling subscribed clients:

```
rails g channel GraphqlChannel
```

```
# app/channels/graphql_channel.rb

class GraphqlChannel < ApplicationCable::Channel
  def subscribed
    @subscription_ids = []
  end

  def execute(data)
    result = execute_query(data)

    payload = {
      result: result.subscription? ? { data: nil } : result.to_h,
      more: result.subscription?
    }

    @subscription_ids << context[:subscription_id] if result.context[:subscription_id]

    transmit(payload)
  end

  def unsubscribed
    @subscription_ids.each do |sid|
      ApuLibrarySchema.subscriptions.delete_subscription(sid)
    end
  end

  private

  def execute_query(data)
    ApuLibrarySchema.execute(
      query: data["query"],
      context: context,
      variables: data["variables"],
      operation_name: data["operationName"]
    )
  end

  def context
    {
      current_user_id: current_user&.id,
      current_user: current_user,
      channel: self
    }
  end
end
```

Now we need to add a way to fetch current user in our channel.

```
# app/channels/application_cable/connection.rb

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = current_user
    end

    private

    def current_user
      token = request.params[:token].to_s
      email = Base64.decode64(token)
      User.find_by(email: email)
    end
  end
end
```

### Plugin in

Install some new modules to deal with Subscriptions via ActionCable:

```
yarn add actioncable graphql-ruby-client
```

Update /app/javascript/utils/apollo.js to add some magic!

Create a new component:

```
npx @hellsquirrel/create-gql-component create /app/javascript/components/Subscription
```

Next, add subscription to /app/javascript/components/Subscription/operations.graphql
Next, create the Subscription component
The last step is to add Subscription component to Library at the end of the last div inside Query component

### Mutations