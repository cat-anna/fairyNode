
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

var base_url = "/api"

class HttpHandler {
    get_json(path: string) {
        let url = base_url + path;
        // console.log("GET " + url)
        return fetch(url, {
            method: 'get',
            headers: {
              'content-type': 'application/json'
            }
          })
            .then(res => res.json())
            // .then(res => {
            //   // a non-200 response code
            //   // if (!res.ok) {
            // //     // create error instance with HTTP status text
            //   //   const error = new Error(res.statusText);
            //   //   error.json = res.json();
            //   //   throw error;
            //   // }
            //   var r = res.json()
            //   console.log(r);
            //   return r
            // })
            // .then(json => {
            //   // set the response data
            //   data.value = json.data;
            // })
            .catch(err => {
                console.log(err);
                throw err
              //     error.value = err;
            //   // In case a custom JSON error response was provided
            //   if (err.json) {
            //     return err.json.then(json => {
            //       // set the JSON response message
            //       error.value.message = json.message;
            //     });
            //   }
            })
            // .then(() => {
            //   loading.value = false;
            // })
            ;
    }

    post_json(path: string, data: object) {
      let url = base_url + path;
      console.log("POST " + url)
      return fetch(url, {
          method: 'post',
          body: JSON.stringify(data),
          headers: {
            'content-type': 'application/json'
          }
        })
          .then(res => res.json())
          // .then(res => {
          //   // a non-200 response code
          //   // if (!res.ok) {
          // //     // create error instance with HTTP status text
          //   //   const error = new Error(res.statusText);
          //   //   error.json = res.json();
          //   //   throw error;
          //   // }
          //   var r = res.json()
          //   console.log(r);
          //   return r
          // })
          // .then(json => {
          //   // set the response data
          //   data.value = json.data;
          // })
          .catch(err => {
              console.log(err);
              throw err
          //     error.value = err;
          //   // In case a custom JSON error response was provided
          //   if (err.json) {
          //     return err.json.then(json => {
          //       // set the JSON response message
          //       error.value.message = json.message;
          //     });
          //   }
          })
          // .then(() => {
          //   loading.value = false;
          // })
          ;
  }

}

export default new HttpHandler()
