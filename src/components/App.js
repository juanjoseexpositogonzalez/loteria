import React, { Component } from 'react';
import { BrowserRouter, Route, Routes } from "react-router-dom";

import Tokens from './Tokens';
import Footer from './Footer';

class App extends Component {
    
    render() {
        return (
            <BrowserRouter>
                <div className="App">
                    <div>
                        <Routes>
                            <Route path="/" element={<Tokens />} />
                        </Routes>
                    </div>
                    <Footer />
                </div>
            </BrowserRouter>
        );
    }

}

export default App;