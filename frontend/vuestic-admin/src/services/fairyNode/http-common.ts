// function fetchData() {
//     // loading.value = true;
//     // I prefer to use fetch
//     // you can use use axios as an alternative
//     return fetch('http://jsonplaceholder.typicode.com/posts', {
//       method: 'get',
//       headers: {
//         'content-type': 'application/json'
//       }
//     })
//       .then(res => {
//         // a non-200 response code
//         if (!res.ok) {
//           // create error instance with HTTP status text
//           const error = new Error(res.statusText);
//           error.json = res.json();
//           throw error;
//         }

//         return res.json();
//       })
//       .then(json => {
//         // set the response data
//         data.value = json.data;
//       })
//       .catch(err => {
//         error.value = err;
//         // In case a custom JSON error response was provided
//         if (err.json) {
//           return err.json.then(json => {
//             // set the JSON response message
//             error.value.message = json.message;
//           });
//         }
//       })
//       .then(() => {
//         loading.value = false;
//       });
//   }

const base_url = '/api'

class HttpError {
  message: string
  status: number
  statusText: string

  constructor(message: string, status: number, statusText: string) {
    this.message = message
    this.status = status
    this.statusText = statusText
  }
}

export interface GenericResult {
  success: boolean
  message?: string
}

class HttpHandler {
  get_json(path: string) {
    const url = base_url + path
    // console.log("GET " + url)
    return fetch(url, {
      method: 'get',
      headers: {
        'content-type': 'application/json',
      },
    }).then((response: Response) => {
      if (response.ok) {
        return response.json()
      }
      throw new HttpError('Something went wrong', response.status, response.statusText)
    })
  }

  post_json(path: string, data: object) {
    const url = base_url + path
    console.log('POST ' + url)
    return fetch(url, {
      method: 'post',
      body: JSON.stringify(data),
      headers: {
        'content-type': 'application/json',
      },
    }).then((response) => {
      if (response.ok) {
        return response.json()
      }
      throw new HttpError('Something went wrong', response.status, response.statusText)
    })
  }
}

export default new HttpHandler()
