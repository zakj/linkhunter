const el = document.querySelector('form > input[value="reset_api_token"] ~ div');
// TODO alert/log to mixpanel if el is not detected
const token = el.textContent;
chrome.runtime.sendMessage({type: 'updateToken', token});
