const {BundleAnalyzerPlugin} = require('webpack-bundle-analyzer');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const UglifyJsWebpackPlugin = require('uglifyjs-webpack-plugin');
const autoprefixer = require('autoprefixer');
const path = require('path');
const webpack = require('webpack');

const srcDir = path.resolve(__dirname, 'src');
const distDir = path.resolve(__dirname, 'dist');

module.exports = (env={}) => {
  const cfg = {
    context: srcDir,

    entry: {
      events: './events',
      'find-api-token': './find-api-token',
      popup: './popup',
      vendor: [
        'animejs',
        // 'mixpanel-browser',
        'moment',
        'vue',
        'vue-focus',
        'vue-router',
        'vue-virtual-scroll-list',
        'vuex',
      ],
    },

    output: {
      path: distDir,
      filename: '[name].js',
    },

    resolve: {
      alias: {
        '@': srcDir,
      },
      extensions: ['.js', '.vue'],
    },

    module: {
      rules: [
        {
          test: /\.js$/,
          include: srcDir,
          loader: 'babel-loader',
        },
        {
          test: /\.vue$/,
          loader: 'vue-loader',
          options: {
            cssModules: {
              localIdentName: '[local]--[hash:base64:5]',
              camelCase: true,
            },
            postcss: [autoprefixer],
          },
        },
        {
          // Disable ejs for HtmlWebpackPlugin to speed up builds.
          test: /\.html$/,
          include: srcDir,
          loader: 'html-loader',
        },
      ],
    },

    plugins: [
      new webpack.IgnorePlugin(/^\.\/locale$/, /moment$/),  // exclude i18n
      new webpack.DefinePlugin({
        MIXPANEL_TOKEN: '6cc73b1df12b2e1ba0892da5da2a7216',
        DEBUG: !env.production,
      }),
      new webpack.optimize.CommonsChunkPlugin({
        name: 'vendor',
        chunks: ['popup'],
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
    ],

    devtool: env.production ? false : 'source-map',
    target: 'web',
  };

  if (env.production) {
    cfg.plugins.push(new UglifyJsWebpackPlugin());
  }
  if (env.analyze) {
    cfg.plugins.push(new BundleAnalyzerPlugin());
  }

  return cfg;
};
