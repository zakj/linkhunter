const CopyWebpackPlugin = require('copy-webpack-plugin');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const UglifyJsWebpackPlugin = require('uglifyjs-webpack-plugin');
const path = require('path');
const webpack = require('webpack');

const srcDir = path.resolve(__dirname, 'src');
const distDir = path.resolve(__dirname, 'dist');

module.exports = (env={}) => ({
  context: srcDir,

  entry: {
    events: './events',
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
    new CopyWebpackPlugin([{
      context: __dirname,
      from: 'manifest.json',
    }]),
    new HtmlWebpackPlugin({
      chunks: ['popup'],
      filename: 'popup.html',
      template: 'popup.html',
      title: 'Linkhunter',
    }),
    new HtmlWebpackPlugin({
      chunks: [],
      filename: 'options.html',
      template: 'options.html',
      title: 'Linkhunter options',
    }),
  ].concat(env.production ? [new UglifyJsWebpackPlugin()] : []),

  devtool: env.production ? false : 'source-map',
  target: 'web',
});
