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
      MartianLibrarySchema.execute(query).as_json
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
