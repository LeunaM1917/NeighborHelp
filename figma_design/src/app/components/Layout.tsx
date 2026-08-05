import { MapPin, ChevronDown, Home } from 'lucide-react';
import { Link, useLocation } from 'react-router';
import { ImageWithFallback } from './figma/ImageWithFallback';
import { useState, useRef, useEffect } from 'react';

export default function Layout({ children }: { children: React.ReactNode }) {
  const location = useLocation();
  const [selectedLocation, setSelectedLocation] = useState('Panabo City');
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const davaoRegionLocations = [
    {
      province: 'Davao del Norte',
      cities: ['Panabo City', 'Tagum City', 'Island Garden City of Samal'],
      municipalities: ['Asuncion', 'Braulio E. Dujali', 'Carmen', 'Kapalong', 'New Corella', 'San Isidro', 'Santo Tomas', 'Talaingod']
    },
    {
      province: 'Davao del Sur',
      cities: ['Davao City', 'Digos City'],
      municipalities: ['Bansalan', 'Hagonoy', 'Kiblawan', 'Magsaysay', 'Malalag', 'Matanao', 'Padada', 'Santa Cruz', 'Sulop']
    },
    {
      province: 'Davao Oriental',
      cities: ['Mati City'],
      municipalities: ['Baganga', 'Banaybanay', 'Boston', 'Caraga', 'Cateel', 'Governor Generoso', 'Lupon', 'Manay', 'San Isidro', 'Tarragona']
    },
    {
      province: 'Davao Occidental',
      cities: [],
      municipalities: ['Don Marcelino', 'Jose Abad Santos', 'Malita', 'Santa Maria', 'Sarangani']
    },
    {
      province: 'Davao de Oro',
      cities: [],
      municipalities: ['Compostela', 'Laak', 'Mabini', 'Maco', 'Maragusan', 'Mawab', 'Monkayo', 'Montevista', 'Nabunturan', 'New Bataan', 'Pantukan']
    }
  ];

  const isActive = (path: string) => location.pathname === path;

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleLocationSelect = (loc: string) => {
    setSelectedLocation(loc);
    setIsDropdownOpen(false);
  };

  return (
    <div className="size-full overflow-auto bg-white">
      {/* Header */}
      <header className="border-b border-gray-200 bg-white sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <Link to="/" className="flex items-center gap-3">
              <ImageWithFallback
                src="../../imports/689227648_809030255334603_3730778276829339656_n-removebg-preview-1.png"
                alt="NeighborHelp"
                className="h-16 w-auto"
              />
              <span className="font-bold text-2xl">
                <span className="text-[#1e3a5f]">Neighbor</span>
                <span className="text-[#4a7c2c]">Help</span>
              </span>
            </Link>

            <nav className="hidden md:flex items-center gap-8">
              <Link
                to="/"
                className={`cursor-pointer transition-colors ${
                  isActive('/')
                    ? 'text-[#1e3a5f] border-b-2 border-[#1e3a5f] pb-1 font-semibold'
                    : 'text-gray-700 hover:text-[#1e3a5f]'
                }`}
              >
                Home
              </Link>
              <Link
                to="/browse-services"
                className={`cursor-pointer transition-colors ${
                  isActive('/browse-services')
                    ? 'text-[#1e3a5f] border-b-2 border-[#1e3a5f] pb-1 font-semibold'
                    : 'text-gray-700 hover:text-[#1e3a5f]'
                }`}
              >
                Browse Services
              </Link>
              <Link
                to="/how-it-works"
                className={`cursor-pointer transition-colors ${
                  isActive('/how-it-works')
                    ? 'text-[#1e3a5f] border-b-2 border-[#1e3a5f] pb-1 font-semibold'
                    : 'text-gray-700 hover:text-[#1e3a5f]'
                }`}
              >
                How It Works
              </Link>
              <Link
                to="/for-providers"
                className={`cursor-pointer transition-colors ${
                  isActive('/for-providers')
                    ? 'text-[#1e3a5f] border-b-2 border-[#1e3a5f] pb-1 font-semibold'
                    : 'text-gray-700 hover:text-[#1e3a5f]'
                }`}
              >
                For Providers
              </Link>
              <Link
                to="/about-us"
                className={`cursor-pointer transition-colors ${
                  isActive('/about-us')
                    ? 'text-[#1e3a5f] border-b-2 border-[#1e3a5f] pb-1 font-semibold'
                    : 'text-gray-700 hover:text-[#1e3a5f]'
                }`}
              >
                About Us
              </Link>
            </nav>

            <div className="flex items-center gap-3">
              <div className="relative" ref={dropdownRef}>
                <button
                  onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                  className="flex items-center gap-2 px-3 py-2 text-gray-700 hover:bg-gray-50 rounded-lg cursor-pointer transition-colors"
                >
                  <MapPin className="w-4 h-4" />
                  <span className="text-sm">{selectedLocation}, PH</span>
                  <ChevronDown className={`w-4 h-4 transition-transform ${isDropdownOpen ? 'rotate-180' : ''}`} />
                </button>

                {isDropdownOpen && (
                  <div className="absolute top-full mt-2 left-0 bg-white border-2 border-gray-200 rounded-lg shadow-xl w-72 max-h-96 overflow-y-auto z-50">
                    <div className="p-2">
                      {davaoRegionLocations.map((provinceData, provinceIndex) => (
                        <div key={provinceData.province} className={provinceIndex > 0 ? 'mt-3 pt-3 border-t border-gray-200' : ''}>
                          <div className="px-3 py-2 text-xs font-bold text-[#1e3a5f] uppercase">
                            {provinceData.province}
                          </div>

                          {provinceData.cities.length > 0 && (
                            <>
                              <div className="px-3 py-1 text-xs font-semibold text-gray-500">Cities</div>
                              {provinceData.cities.map((city) => (
                                <button
                                  key={`${city}-${provinceData.province}`}
                                  onClick={() => handleLocationSelect(city)}
                                  className={`w-full text-left px-3 py-2 text-sm rounded-md hover:bg-[#e8eef5] cursor-pointer transition-colors ${
                                    selectedLocation === city ? 'bg-[#e8eef5] text-[#1e3a5f] font-semibold' : 'text-gray-700'
                                  }`}
                                >
                                  {city}
                                </button>
                              ))}
                            </>
                          )}

                          {provinceData.municipalities.length > 0 && (
                            <>
                              <div className="px-3 py-1 text-xs font-semibold text-gray-500 mt-1">Municipalities</div>
                              {provinceData.municipalities.map((municipality) => (
                                <button
                                  key={`${municipality}-${provinceData.province}`}
                                  onClick={() => handleLocationSelect(municipality)}
                                  className={`w-full text-left px-3 py-2 text-sm rounded-md hover:bg-[#e8eef5] cursor-pointer transition-colors ${
                                    selectedLocation === municipality ? 'bg-[#e8eef5] text-[#1e3a5f] font-semibold' : 'text-gray-700'
                                  }`}
                                >
                                  {municipality}
                                </button>
                              ))}
                            </>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              <button className="px-4 py-2 text-gray-700 hover:bg-gray-50 rounded-lg cursor-pointer transition-colors">
                Log In
              </button>
              <Link to="/signup">
                <button className="px-4 py-2 bg-[#1e3a5f] text-white rounded-lg hover:bg-[#152d47] cursor-pointer transition-colors">
                  Sign Up
                </button>
              </Link>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main>{children}</main>

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid md:grid-cols-4 gap-8">
            <div>
              <div className="flex items-center gap-3 mb-4">
                <ImageWithFallback
                  src="../../imports/689227648_809030255334603_3730778276829339656_n.jpg"
                  alt="NeighborHelp"
                  className="h-20 w-auto rounded-lg"
                />
                <span className="font-bold text-2xl text-white">
                  <span className="text-[#6b9bd1]">Neighbor</span>
                  <span className="text-[#7fb857]">Help</span>
                </span>
              </div>
              <p className="text-gray-400 text-sm">
                Connecting communities with trusted local service providers.
              </p>
            </div>
            <div>
              <h4 className="font-semibold mb-4">For Customers</h4>
              <ul className="space-y-2 text-gray-400 text-sm">
                <li>
                  <Link to="/browse-services" className="hover:text-white cursor-pointer transition-colors">
                    Browse Services
                  </Link>
                </li>
                <li>
                  <Link to="/how-it-works" className="hover:text-white cursor-pointer transition-colors">
                    How It Works
                  </Link>
                </li>
                <li>
                  <a href="#" className="hover:text-white cursor-pointer transition-colors">
                    Safety
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="font-semibold mb-4">For Providers</h4>
              <ul className="space-y-2 text-gray-400 text-sm">
                <li>
                  <Link to="/for-providers" className="hover:text-white cursor-pointer transition-colors">
                    Become a Provider
                  </Link>
                </li>
                <li>
                  <a href="#" className="hover:text-white cursor-pointer transition-colors">
                    Resources
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-white cursor-pointer transition-colors">
                    Success Stories
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <h4 className="font-semibold mb-4">Company</h4>
              <ul className="space-y-2 text-gray-400 text-sm">
                <li>
                  <Link to="/about-us" className="hover:text-white cursor-pointer transition-colors">
                    About Us
                  </Link>
                </li>
                <li>
                  <a href="#" className="hover:text-white cursor-pointer transition-colors">
                    Contact
                  </a>
                </li>
                <li>
                  <a href="#" className="hover:text-white cursor-pointer transition-colors">
                    Privacy Policy
                  </a>
                </li>
              </ul>
            </div>
          </div>
          <div className="border-t border-gray-800 mt-8 pt-8 text-center text-gray-400 text-sm">
            © 2026 NeighborHelp. All rights reserved.
          </div>
        </div>
      </footer>
    </div>
  );
}
