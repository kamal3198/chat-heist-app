export async function searchUsersByUsername({ query, idToken }) {
  if (!idToken) {
    throw new Error('Missing ID token');
  }

  const apiBaseUrl = process.env.REACT_APP_API_BASE_URL;
  const url = `${apiBaseUrl}/users/search?username=${encodeURIComponent(query)}`;

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${idToken}`,
    },
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error || `Search failed (${response.status})`);
  }

  return data;
}

