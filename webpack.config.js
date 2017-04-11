const CopyWebpackPlugin = require('copy-webpack-plugin');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const UglifyJsWebpackPlugin = require('uglifyjs-webpack-plugin');
const path = require('path');
const webpack = require('webpack');
const autoprefixer = require('autoprefixer');

const srcDir = path.resolve(__dirname, 'src');
const distDir = path.resolve(__dirname, 'dist');

module.exports = (env={}) => ({
  context: srcDir,

  entry: {
    vendor: ['panel'],
    events: './events',
    options: './options',
    popup: './popup',
    'find-api-token': './find-api-token',
  },

  output: {
    path: distDir,
    filename: '[name].js',
  },

  module: {
    rules: [
      {
        test: /\.js$/,
        include: srcDir,
        loader: 'babel-loader',
        options: {
          compact: false,
          presets: ['es2015'],
        },
      },
      {
        test: /\.jade$/,
        include: srcDir,
        loader: 'virtual-jade-loader',
        options: {
          vdom: 'snabbdom',
          runtime: 'var h = require("panel").h;',
        },
      },
      {
        test: /\.styl/,
        loader: [
          'style-loader',
          'css-loader',
          {
            loader: 'postcss-loader',
            options: {plugins: () => [autoprefixer]},
          },
          'stylus-loader',
        ],
      },
      {
        // Disable ejs for HtmlWebpackPlugin to speed up builds.
        test: /\.html/,
        include: srcDir,
        loader: 'html-loader',
      },
    ],
  },

  plugins: [
    new webpack.DefinePlugin({
      MIXPANEL_TOKEN: '6cc73b1df12b2e1ba0892da5da2a7216',
      DEBUG: !env.production,
    }),
    new webpack.optimize.CommonsChunkPlugin({
      name: 'vendor',
      chunks: ['options', 'popup'],
    }),
    new CopyWebpackPlugin([{
      context: __dirname,
      from: 'manifest.json',
    }]),
    new HtmlWebpackPlugin({
      chunks: ['vendor', 'popup'],
      template: 'popup/index.html',
      filename: 'popup.html',
      title: 'Linkhunter',
    }),
    new HtmlWebpackPlugin({
      chunks: ['vendor', 'options'],
      template: 'options/index.html',
      filename: 'options.html',
      title: 'Linkhunter options',
    }),
  ].concat(env.production ? [new UglifyJsWebpackPlugin()] : []),

  devtool: env.production ? false : 'source-map',
  target: 'web',
});
