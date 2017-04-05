function tabCreated(tab) {
  chrome.tabs.executeScript(tab.id,
    {
      file: 'find-api-token.js',
      runAt: 'document_end',
    },
    // Defer closing until sendMessage can complete.
    () => setTimeout(() => chrome.tabs.remove([tab.id]), 250));
}

chrome.storage.local.get('bookmarks', ({bookmarks}) => {
  if (!bookmarks) return;
  const frag = document.createDocumentFragment();
  bookmarks.forEach(b => {
    const item = document.createElement('li');
    const img = document.createElement('img');
    const link = document.createElement('a');

    link.href = b.href;
    link.textContent = b.description;

    img.width = 16
    img.height = 16;
    img.src = `https://icons.duckduckgo.com/ip2/${link.host}.ico`;

    item.appendChild(img);
    item.appendChild(link);
    frag.appendChild(item);
  });
  document.querySelector('ul').appendChild(frag);
  document.body.classList.add('loaded');
});

chrome.storage.local.get('token', ({token}) => {
  if (token) return;
  chrome.tabs.create(
    {url: 'https://pinboard.in/settings/password', active: false},
    tabCreated);
});

document.getElementById('options').addEventListener('click', () => chrome.runtime.openOptionsPage())
