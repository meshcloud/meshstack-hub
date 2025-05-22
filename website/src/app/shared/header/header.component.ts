import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';

import { SearchBarComponent } from '../search-bar/search-bar.component';
import { NgbTooltipModule } from '@ng-bootstrap/ng-bootstrap';

@Component({
  selector: 'mst-header',
  imports: [CommonModule, SearchBarComponent, NgbTooltipModule],
  templateUrl: './header.component.html',
  styleUrl: './header.component.scss',
  standalone: true
})
export class HeaderComponent {
}
