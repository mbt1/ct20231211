import './App.css';
import React,{useState, useEffect} from 'react';
//import ViewNotebook from 'react-jupyter-notebook';
import { JupyterNotebookViewer } from "react-jupyter-notebook-viewer";
const bucket_url = 'https://ct20231211-reports.s3.amazonaws.com/'

// function App() {
//   // const [files, setFiles] = useState([]);
//   // const [selectedFileURL, setSelectedFile] = useState('');
//   const [notebookContent, setNotebookContent] = useState(null);

//   useEffect(() => {
//     const fetchFiles = async () => {
//       try {
//         const response = await fetch(bucket_url);
//         const data = await response.text();
//         const parser = new DOMParser();
//         const xml = parser.parseFromString(data, "application/xml");
//         const elements = xml.getElementsByTagName("Key");
//         const fileNames = Array.from(elements).map(element => element.textContent).sort((a,b)=>b.localeCompare(a));
//         const NotebookURL = bucket_url+fileNames[0]
//         const response2 = await fetch(NotebookURL);
//         const data2 = await response2.json();
//         console.log(4,data2)
//         setNotebookContent(NotebookURL);
//       } catch (error) {
//         console.error("Error fetching file list: ", error);
//       }
//     };
  
//     fetchFiles();
//   }, []);
  

//   return (
//     <div className="App">
//       <header className="App-header">
//         <h1>
//           <img src={`${process.env.PUBLIC_URL}/logo192.png`} className="App-logo" alt="logo" />
//           A simple .ipynb report viewer
//         </h1>
//       </header>
//       <div>
//         {/* <select value={selectedFileURL} onChange={handleFileChange}>
//           {files.map(file => (
//             <option key={file} value={bucket_url+file}>{file}</option>
//           ))}
//         </select> */}
//         <DisplayNotebook notebook={notebookContent} />
//       </div>
//     </div>
//   );
// }
function App() {
  const [files, setFiles] = useState([]);
  const [selectedFileURL, setSelectedFile] = useState('');

  useEffect(() => {
    const fetchFiles = async () => {
      try {
        const response = await fetch(bucket_url);
        const data = await response.text();
        parseXML(data);
      } catch (error) {
        console.error("Error fetching file list: ", error);
      }
    };
  
    fetchFiles();
  }, []);
  
  const parseXML = (xmlData) => {
    const parser = new DOMParser();
    const xml = parser.parseFromString(xmlData, "application/xml");
    const elements = xml.getElementsByTagName("Key");
    const fileNames = Array.from(elements).map(element => element.textContent).sort((a,b)=>b.localeCompare(a));
    setFiles(fileNames);
    if (fileNames.length > 0) {
      setSelectedFile(bucket_url+fileNames[0]);
    }
  };

  const handleFileChange = (event) => {
    console.log(1, event.target.value)
    setSelectedFile(null);
    setTimeout(() => {
      setSelectedFile(event.target.value);
    }, 100)
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>
          <img src={`${process.env.PUBLIC_URL}/logo192.png`} className="App-logo" alt="logo" />
          A simple .ipynb report viewer
        </h1>
      </header>
      <div>
        Select the report to display: 
        <select value={selectedFileURL} onChange={handleFileChange}>
          {files.map(file => (
            <option key={file} value={bucket_url+file}>{file}</option>
          ))}
        </select>
      </div>
      <div>
        <DisplayNotebook notebook={selectedFileURL} />
      </div>
      <div>
        Download <a href={selectedFileURL}>{selectedFileURL.substring(bucket_url.length)}</a>.
      </div>
    </div>
  );
}

function DisplayNotebook(props) {
  console.log(5, props.notebook)
  if(null==props.notebook){
    console.log(5,"is NULL")
    return <></>
  }
  console.log(5,"is not NULL")
  return <><JupyterNotebookViewer 
              filePath={props.notebook} 
              outputDarkTheme="true"
              className = "NotebookViewer"
            /></>
}
export default App;
