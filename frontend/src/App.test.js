import React from 'react';
import { createRoot } from 'react-dom/client';
import { act } from 'react';
import App from './App';

global.fetch = jest.fn();
global.IS_REACT_ACT_ENVIRONMENT = true;

describe('App Component', () => {
  let container;
  let root;

  beforeEach(() => {
    fetch.mockReset();
    fetch.mockResolvedValue({
      ok: true,
      json: async () => []
    });

    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(() => {
    act(() => {
      root.unmount();
    });
    container.remove();
  });

  test('renders TaskFlow heading', async () => {
    await act(async () => {
      root.render(<App />);
    });

    const heading = container.querySelector('h1');
    expect(heading).not.toBeNull();
    expect(heading.textContent).toContain('TaskFlow');
    expect(fetch).toHaveBeenCalled();
  });

  test('renders task form', async () => {
    await act(async () => {
      root.render(<App />);
    });

    const titleInput = container.querySelector('input[placeholder="Enter task title..."]');
    expect(titleInput).not.toBeNull();
    expect(fetch).toHaveBeenCalled();
  });

  test('fetches tasks on mount', async () => {
    await act(async () => {
      root.render(<App />);
    });

    expect(fetch).toHaveBeenCalledWith(expect.stringContaining('/api/tasks'), expect.anything());
  });
});
