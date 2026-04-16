import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';

import { SearchBarComponent } from '../search-bar/search-bar.component';

@Component({
  selector: 'mst-header',
  imports: [CommonModule, SearchBarComponent, RouterLink],
  templateUrl: './header.component.html',
  styleUrl: './header.component.scss',
  standalone: true
})
export class HeaderComponent {
}
