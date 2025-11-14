module.exports = function (api) {
  api.cache(true);
  return {
    presets: [
      'babel-preset-expo',
      '@babel/preset-env',
      '@babel/preset-react'
    ],
    plugins: [
      'react-native-worklets/plugin',
      '@babel/plugin-proposal-export-namespace-from',
      '@babel/plugin-proposal-class-properties'
    ],
    env: {
      production: {
        plugins: ['react-native-paper/babel']
      }
    }
  };
};