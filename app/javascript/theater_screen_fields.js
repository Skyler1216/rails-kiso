// Nested screenフォームの動的追加・削除を扱う。Importmapから読み込まれ、同ページ遷移でも動くよう Turbo イベントを監視する。
const INIT_ATTR = 'data-screen-fields-initialized';

// Turbo + 直接読み込みの両方に対応した DOM ready ヘルパ
function ready(callback) {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', callback);
  } else {
    callback();
  }

  document.addEventListener('turbo:load', callback);
}

// 各フォーム（data-screen-fields を持つ article）毎にイベントをバインド
function setupContainer(container) {
  if (container.hasAttribute(INIT_ATTR)) return;
  container.setAttribute(INIT_ATTR, 'true');

  const list = container.querySelector('[data-screen-fields-list]');
  const template = container.querySelector('template[data-screen-fields-template]');
  const addButton = container.querySelector('[data-screen-fields-add]');

  if (list && !container.dataset.screenFieldsNextIndex) {
    container.dataset.screenFieldsNextIndex = list.querySelectorAll('[data-screen-fields-item]').length;
  }

  if (addButton && template && list) {
    addButton.addEventListener('click', () => {
      // nested attributes は数値キーを期待するため、連番インデックスを使って child_index を置換する
      const nextIndex = parseInt(container.dataset.screenFieldsNextIndex || '0', 10);
      container.dataset.screenFieldsNextIndex = nextIndex + 1;

      const html = template.innerHTML.replace(/NEW_SCREEN/g, nextIndex);
      const wrapper = document.createElement('div');
      wrapper.innerHTML = html.trim();
      const field = wrapper.firstElementChild;
      if (field) list.appendChild(field);
    });
  }

  container.addEventListener('click', (event) => {
    const button = event.target.closest('[data-screen-fields-remove]');
    if (!button) return;

    const item = button.closest('[data-screen-fields-item]');
    if (!item) return;

    const destroyInput = item.querySelector('input[data-screen-destroy-flag]');
    const textInput = item.querySelector('input[type="text"], textarea, select');
    const isPersisted = button.dataset.persisted === 'true';

    if (isPersisted && destroyInput) {
      // 永続済みレコードは `_destroy` フラグをトグル。UI も disabled / opacity で反映する。
      const isMarked = destroyInput.value === '1';
      if (isMarked) {
        destroyInput.value = '0';
        item.classList.remove('opacity-50');
        button.textContent = button.dataset.removeLabel || '削除';
        if (textInput) textInput.disabled = false;
      } else {
        destroyInput.value = '1';
        item.classList.add('opacity-50');
        button.textContent = button.dataset.undoLabel || '削除を取り消す';
        if (textInput) textInput.disabled = true;
      }
    } else {
      // 未保存行は単純に DOM から除去
      item.remove();
    }
  });
}

ready(() => {
  // Turbo遷移でも重複バインドしないように setupContainer 内でガード
  document.querySelectorAll('[data-screen-fields]').forEach(setupContainer);
});
