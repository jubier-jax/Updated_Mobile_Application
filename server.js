
const express = require('express');

const app = express();

app.use(express.json());

const products = [
  {
    id: '1',
    name: 'Paracetamol',
    category: 'ওষুধ',
    price: 20,
    location: 'চাঁদপুর সদর'
  },
  {
    id: '2',
    name: 'রুই মাছ',
    category: 'খাবার',
    price: 350,
    location: 'চাঁদপুর সদর'
  },
  {
    id: '3',
    name: 'Type-C Charger',
    category: 'ইলেকট্রনিক্স',
    price: 450,
    location: 'হাজীগঞ্জ'
  }
];

app.get('/', (req, res) => {
  res.json({
    message: 'Nearby Availability REST API is running'
  });
});

app.get('/api/products', (req, res) => {
  const search = (req.query.search || '').toLowerCase();

  const result = products.filter(product =>
    product.name.toLowerCase().includes(search) ||
    product.category.toLowerCase().includes(search)
  );

  res.json({
    success: true,
    count: result.length,
    data: result
  });
});

app.listen(3000, () => {
  console.log('API running at http://localhost:3000');
});
